// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title Marketplace (C4, Q3): publicaciones a precio fijo con escrow en BRLT y disputas.
/// @notice El activo permanece en escrow en este contrato hasta que el comprador confirma.
contract Marketplace is AccessControl, ReentrancyGuard, IERC1155Receiver {
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
    IERC20 public immutable brlt;

    enum State { Active, Funded, Completed, Cancelled, Disputed, Refunded }

    struct Listing {
        address seller;
        address buyer;
        address token;
        uint256 tokenId;
        uint256 quantity;
        uint256 price; // precio total por toda la cantidad
        bool isERC1155;
        State state;
    }

    Listing[] public listings;
    mapping(address => bool) public approvedToken;

    event ListingCreated(uint256 indexed listingId, address indexed seller, address token, uint256 tokenId, uint256 price);
    event ListingPurchased(uint256 indexed listingId, address indexed buyer, uint256 amount);
    event ListingCompleted(uint256 indexed listingId, address indexed seller, address indexed buyer);
    event ListingCancelled(uint256 indexed listingId);
    event DisputeOpened(uint256 indexed listingId, address indexed openedBy);
    event DisputeResolved(uint256 indexed listingId, bool releasedToBuyer);

    error NotSeller();
    error NotBuyer();
    error InvalidState();
    error InvalidPrice();
    error TokenNotApproved();

    constructor(address admin_, address brlt_) {
        require(admin_ != address(0) && brlt_ != address(0), "params");
        brlt = IERC20(brlt_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ARBITER_ROLE, admin_);
    }

    function setTokenApproved(address token, bool approved) external onlyRole(DEFAULT_ADMIN_ROLE) {
        approvedToken[token] = approved;
    }

    /// @notice Publica un activo: el vendedor transfiere el activo al escrow.
    function createListing(
        address token,
        uint256 tokenId,
        uint256 quantity,
        uint256 price,
        bool isERC1155
    ) external nonReentrant returns (uint256 listingId) {
        if (!approvedToken[token]) revert TokenNotApproved();
        if (price == 0 || quantity == 0) revert InvalidPrice();

        if (isERC1155) {
            IERC1155(token).safeTransferFrom(msg.sender, address(this), tokenId, quantity, "");
        } else {
            require(quantity == 1, "cantidad invalida");
            IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        }

        listingId = listings.length;
        listings.push(
            Listing({
                seller: msg.sender,
                buyer: address(0),
                token: token,
                tokenId: tokenId,
                quantity: quantity,
                price: price,
                isERC1155: isERC1155,
                state: State.Active
            })
        );
        emit ListingCreated(listingId, msg.sender, token, tokenId, price);
    }

    /// @notice Compra: el BRLT queda en escrow en el contrato.
    function buy(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        if (l.state != State.Active) revert InvalidState();
        l.buyer = msg.sender;
        l.state = State.Funded;
        require(brlt.transferFrom(msg.sender, address(this), l.price), "brlt");
        emit ListingPurchased(listingId, msg.sender, l.price);
    }

    /// @notice El comprador confirma la recepción: se libera el pago y el activo.
    function confirmReceipt(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        if (l.state != State.Funded || l.buyer != msg.sender) revert InvalidState();
        l.state = State.Completed;
        _deliverAsset(l, l.buyer);
        require(brlt.transfer(l.seller, l.price), "brlt");
        emit ListingCompleted(listingId, l.seller, l.buyer);
    }

    /// @notice El vendedor cancela una publicación aún no comprada.
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        if (l.state != State.Active || l.seller != msg.sender) revert NotSeller();
        l.state = State.Cancelled;
        _deliverAsset(l, l.seller);
        emit ListingCancelled(listingId);
    }

    /// @notice El comprador abre una disputa (solo tras pagar).
    function openDispute(uint256 listingId) external {
        Listing storage l = listings[listingId];
        if (l.state != State.Funded || l.buyer != msg.sender) revert NotBuyer();
        l.state = State.Disputed;
        emit DisputeOpened(listingId, msg.sender);
    }

    /// @notice Resolución del árbitro: libera al vendedor o devuelve el BRLT al comprador.
    function resolveDispute(uint256 listingId, bool releaseToSeller)
        external
        onlyRole(ARBITER_ROLE)
        nonReentrant
    {
        Listing storage l = listings[listingId];
        if (l.state != State.Disputed) revert InvalidState();
        if (releaseToSeller) {
            l.state = State.Completed;
            _deliverAsset(l, l.buyer);
            require(brlt.transfer(l.seller, l.price), "brlt");
            emit DisputeResolved(listingId, true);
        } else {
            l.state = State.Refunded;
            _deliverAsset(l, l.seller);
            require(brlt.transfer(l.buyer, l.price), "brlt");
            emit DisputeResolved(listingId, false);
        }
    }

    function _deliverAsset(Listing storage l, address to) internal {
        if (l.isERC1155) {
            IERC1155(l.token).safeTransferFrom(address(this), to, l.tokenId, l.quantity, "");
        } else {
            IERC721(l.token).transferFrom(address(this), to, l.tokenId);
        }
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function listingsCount() external view returns (uint256) {
        return listings.length;
    }

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }
}
