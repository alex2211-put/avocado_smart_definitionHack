// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AdvertisementContract is ERC721Enumerable {

    using SafeMath for uint256;
    using Counters for Counters.Counter;
    string private baseTokenURI;
    uint private basePrice = 10 ** 18;
    uint private constant commission = 10;
    address payable private owner_;
    Counters.Counter private _tokenIds;

    uint private constant baseNumberNFT = 10;
    struct advertisingSpace {
        uint price;
        uint basePrice;
        uint durationInSeconds;
        string domain;
        string name;
        address payable owner;
        uint id;
        uint purchaseTime;
        string html;
        uint height;
        uint width;
        string description;
        address payable creator;
    }

    mapping (uint => uint) numNFTinArr;

    advertisingSpace[] advertisingSpaces;
    mapping (address => bool) blockedWallets;
    mapping (address => bool) blockedSpaceOwners;
    mapping (address => uint[]) spacesByCreators;

    constructor(string memory baseURI) ERC721("NFT Collectible", "NFTC") {
        baseTokenURI = baseURI;
        owner_ = payable(msg.sender);
        for (uint i = 0; i < baseNumberNFT; i++) {
          _mintSingleNFT();
          advertisingSpace memory oneSpace = advertisingSpace(
            {
                price: basePrice, 
                durationInSeconds: 0, 
                domain: "google.com", 
                name: "empty space", 
                owner: owner_, 
                id: _tokenIds.current(),
                purchaseTime: block.timestamp,
                html: "",
                basePrice: basePrice,
                height: 200,
                width: 300,
                description: "",
                creator: owner_
            });
          advertisingSpaces.push(oneSpace);
          numNFTinArr[oneSpace.id] = i + 1;
          spacesByCreators[owner_].push(oneSpace.id);
        }
    }

    function _mintSingleNFT() private {
      uint newTokenID = _tokenIds.current();
      _safeMint(msg.sender, newTokenID);
      _tokenIds.increment();
    }

    function getAllNFT() external view returns(advertisingSpace[] memory) {
        return advertisingSpaces;
    }

    function getPriceForAdv(uint id) public view returns(uint price) {
        uint numberInArr = _getNumberInArrById(id);
        advertisingSpace storage advertisement = advertisingSpaces[numberInArr];
        if (block.timestamp > (advertisement.purchaseTime + advertisement.durationInSeconds)) {
            return advertisement.basePrice;
        }
        return advertisement.price;
    }

    function _getPriceForAdvBySpace(advertisingSpace memory advertisement) private view returns(uint price) {
        if (block.timestamp > (advertisement.purchaseTime + advertisement.durationInSeconds)) {
            return advertisement.basePrice;
        }
        return advertisement.price;
    }

    function buyAdvertisementSpace(uint id, uint price, uint durationInDays) external payable{
        require(blockedWallets[msg.sender] == false, "Wallet was blocked");
        uint numberInArr = _getNumberInArrById(id);
        advertisingSpace storage advertisement = advertisingSpaces[numberInArr];
        require(price >= _getPriceForAdvBySpace(advertisement), "Price is not correct");
        uint durationInSeconds = durationInDays * 24 * 3600;
        require(msg.value >= price * durationInDays, "Ether value sent is not correct");
        require(advertisement.owner != payable (msg.sender), "Wallet is already own the NFT");
        if (block.timestamp < (advertisement.purchaseTime + advertisement.durationInSeconds)) {
            require(msg.value > advertisement.price * durationInDays, "Ether value sent is not correct");
            returnMoney(advertisement);
        }
        advertisement.price = price;
        advertisement.durationInSeconds = durationInSeconds;
        advertisement.owner = payable (msg.sender);
        advertisement.purchaseTime = block.timestamp;
    }

    function _getNumberInArrById(uint id) internal view returns(uint numberInArr){
        uint num = numNFTinArr[id];
        require(num != 0, "No NFT with such id");
        return num - 1;
    }

    function returnMoney(advertisingSpace memory advertisement) private {
        uint moneyForReturn = advertisement.price * (1 - (block.timestamp - advertisement.purchaseTime) / advertisement.durationInSeconds) * advertisement.durationInSeconds / (24 * 3600);
        advertisement.owner.transfer(moneyForReturn);
    }

    function _removeAdvFromUser(uint id) internal {
        uint numberInArr = _getNumberInArrById(id);
        advertisingSpace storage advertisement = advertisingSpaces[uint(numberInArr)];
        advertisement.owner = advertisement.creator;
        advertisement.html = "";
        advertisement.price = advertisement.basePrice;
    }

    function setHtml(uint id, string calldata html) external {
        uint numberInArr = _getNumberInArrById(id);
        advertisingSpace storage advertisement = advertisingSpaces[uint(numberInArr)];
        require(advertisement.owner == msg.sender, "Wallet does not own this NFT");
        advertisement.html = html;
    }

    function getBalance() external view returns(uint balance) {
        return owner_.balance;
    }

    function addAdvSpace(uint basePriceAdv, string calldata domain, uint height, uint width, string calldata name, string calldata description) external {
            _mintSingleNFT();
            advertisingSpace memory oneSpace = advertisingSpace(
            {
                price: basePriceAdv, 
                durationInSeconds: 0, 
                domain: domain, 
                name: name, 
                owner: payable(msg.sender), 
                id: _tokenIds.current(),
                purchaseTime: block.timestamp,
                html: "",
                basePrice: basePriceAdv,
                height: height,
                width: width,
                description: description,
                creator: payable(msg.sender)
            });
          advertisingSpaces.push(oneSpace);
          numNFTinArr[oneSpace.id] = advertisingSpaces.length;
          spacesByCreators[payable(msg.sender)].push(oneSpace.id);
    }

    function banUser(uint id) external {
        uint numberInArr = _getNumberInArrById(id);
        advertisingSpace storage advertisement = advertisingSpaces[numberInArr];
        require(msg.sender == advertisement.creator, "No access rights for this wallet");
        require(advertisement.creator != advertisement.owner, "The wallet can not ban the creator");
        blockedWallets[advertisement.owner] = true;
        if (block.timestamp < (advertisement.purchaseTime + advertisement.durationInSeconds)) {
            returnMoney(advertisement);
        }
        _removeAdvFromUser(id);
    }

    function banSpaceOwners(uint id) external {
        uint numberInArr = _getNumberInArrById(id);
        advertisingSpace storage advertisement = advertisingSpaces[uint(numberInArr)];
        require(msg.sender == advertisement.owner, "No access rights for this wallet");
        require(advertisement.creator != advertisement.owner, "The wallet can not ban the itself");
        blockedSpaceOwners[advertisement.owner] = true;
        if (block.timestamp < (advertisement.purchaseTime + advertisement.durationInSeconds)) {
            returnMoney(advertisement);
        }
        for (uint i = 0; i < spacesByCreators[advertisement.creator].length; i++) {
            advertisingSpaces[spacesByCreators[advertisement.creator][i]] = advertisingSpaces[advertisingSpaces.length - 1];
            advertisingSpaces.pop();
        }
    }

}
