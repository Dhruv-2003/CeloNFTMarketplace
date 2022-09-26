// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketplace {
    // listing details stored
    struct Listing {
        uint256 price;
        address seller;
    }

    /// mapping from contract address --> token ID --> Listing data
    mapping(address => mapping(uint256 => Listing)) public listings;

    /// important modifiers and conditions that will be checked in all along the NFT contract

    // Requires the msg.sender is the owner of the specified NFT
    modifier isNFTOwner(address nftAddress, uint256 tokenId) {
        require(
            IERC721(nftAddress).ownerOf(tokenId) == msg.sender,
            "MRKT: Not the owner"
        );
        _;
    }

    // Requires that the specified NFT is not already listed for sale
    modifier isNotListed(address nftAddress, uint256 tokenId) {
        require(
            listings[nftAddress][tokenId].price == 0,
            "MRKT: Already listed"
        );
        _;
    }

    // Requires that the specified NFT is already listed for sale
    modifier isListed(address nftAddress, uint256 tokenId) {
        require(listings[nftAddress][tokenId].price > 0, "MRKT: Not listed");
        _;
    }

    /// important events that are emitted

    event ListingCreated(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        address seller
    );

    event ListingCanceled(address nftAddress, uint256 tokenId, address seller);

    event ListingUpdated(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice,
        address seller
    );

    event ListingPurchased(
        address nftAddress,
        uint256 tokenId,
        address seller,
        address buyer
    );

    /// @dev -  Create the listing for the specific NFT we want to sell
    /// @param nftAddress -  address of the nft contract
    /// @param tokenId -  token ID of the NFT from the contract to be put on sale
    /// @param price-  set the intial price of the sale for the NFT
    function createListing(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        isNotListed(nftAddress, tokenId)
        isNFTOwner(nftAddress, tokenId)
    {
        // price is checked,  should be > 0
        require(price > 0, "MRKT: Price must be > 0");

        IERC721 nftContract = IERC721(nftAddress);

        // conditions are checked for the IERC721 contract
        // whether approval is given or not
        require(
            nftContract.isApprovedForAll(msg.sender, address(this)) ||
                nftContract.getApproved(tokenId) == address(this),
            "MRKT: No approval for NFT"
        );

        // added in the listing mapping
        listings[nftAddress][tokenId] = Listing({
            price: price,
            seller: msg.sender
        });

        // event for creation is emitted
        emit ListingCreated(nftAddress, tokenId, price, msg.sender);
    }

    ///@dev To cancel a particular NFT listing on the sale
    ///@param nftAddress- address of the contract for which the listing is to be cancelled
    ///@param tokenId - id of the token to be cancelled
    function cancelListing(address nftAddress, uint256 tokenId)
        external
        isListed(nftAddress, tokenId)
        isNFTOwner(nftAddress, tokenId)
    {
        // Delete the Listing struct from the mapping
        // Freeing up storage saves gas!
        delete listings[nftAddress][tokenId];

        // Emit the event
        emit ListingCanceled(nftAddress, tokenId, msg.sender);
    }

    /// @dev -  to update a current listing of the NFT sale
    /// @param nftAddress -  address of the nft contract
    /// @param tokenId -  token ID of the NFT from the contract to be ipdated
    /// @param newPrice-  set the updated price of the sale for the NFT
    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    ) external isListed(nftAddress, tokenId) isNFTOwner(nftAddress, tokenId) {
        // Cannot update the price to be < 0
        require(newPrice > 0, "MRKT: Price must be > 0");

        // Update the listing price
        listings[nftAddress][tokenId].price = newPrice;

        // Emit the event
        emit ListingUpdated(nftAddress, tokenId, newPrice, msg.sender);
    }

    /// @dev - to purchase the NFT for any current listing and transfer the ETH at the same time
    /// @param nftAddress - address of the nft contract
    /// @param tokenId -  id of the NFT to be purchased
    /// ETH is to be sent for the price in the listing for the function execution to be completed
    function purchaseListing(address nftAddress, uint256 tokenId)
        external
        payable
        isListed(nftAddress, tokenId)
    {
        // Load the listing in a local copy
        Listing memory listing = listings[nftAddress][tokenId];

        // Buyer must have sent enough ETH
        require(msg.value == listing.price, "MRKT: Incorrect ETH supplied");

        // Delete listing from storage, save some gas
        delete listings[nftAddress][tokenId];

        // Transfer NFT from seller to buyer
        IERC721(nftAddress).safeTransferFrom(
            listing.seller,
            msg.sender,
            tokenId
        );

        // Transfer ETH sent from buyer to seller
        (bool sent, ) = payable(listing.seller).call{value: msg.value}("");
        require(sent, "Failed to transfer eth");

        // Emit the event
        emit ListingPurchased(nftAddress, tokenId, listing.seller, msg.sender);
    }
}
