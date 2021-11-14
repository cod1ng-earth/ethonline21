// contracts/StyleNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './ISplicePriceStrategy.sol';
import './StyleSettings.sol';

contract SpliceStyleNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
  using Counters for Counters.Counter;
  using SafeCast for uint256;

  error BadReservationParameters(uint32 reservation, uint32 cap);
  error AllowlistDurationTooShort(uint64 _days);

  /// @notice The style cap has been reached. You can't mint more items using that style
  error MintingCapOnStyleReached();

  /// @notice Sales is not active on the style
  error SaleNotActive(uint32 style_token_id);

  /// @notice Reservation limit exceeded
  error PersonalReservationLimitExceeded(uint32 style_token_id);

  /// @notice
  error NotEnoughTokensToMatchReservation(uint32 style_token_id);

  Counters.Counter private _styleTokenIds;

  mapping(address => bool) public isArtist;
  mapping(uint32 => StyleSettings) styleSettings;
  mapping(uint32 => Allowlist) allowlists;
  mapping(uint32 => mapping(address => uint8)) mintsAlreadyAllowed;

  address public spliceNFT;

  constructor()
    ERC721('Splice Style NFT', 'SPLYLE')
    ERC721Enumerable()
    Ownable()
  {}

  modifier onlyArtist() {
    require(isArtist[msg.sender] == true, 'only artists can mint styles');
    _;
  }

  modifier onlySplice() {
    require(msg.sender == spliceNFT, 'only callable by Splice');
    _;
  }

  function setSplice(address _spliceNFT) external onlyOwner {
    spliceNFT = _spliceNFT;
  }

  function allowArtist(address artist) external onlyOwner {
    isArtist[artist] = true;
  }

  function disallowArtist(address artist) external onlyOwner {
    require(isArtist[artist], "the artist wasn't allowed anyway");
    isArtist[artist] = false;
  }

  /**
   * we assume that our metadata CIDs are folder roots containing a /metadata.json
   * that's how nft.storage does it.
   */
  function _metadataURI(string memory metadataCID)
    private
    pure
    returns (string memory)
  {
    return string(abi.encodePacked('ipfs://', metadataCID, '/metadata.json'));
  }

  //todo: check the 256 => 32 downcast
  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      'ERC721Metadata: URI query for nonexistent token'
    );
    string memory metadataCID = styleSettings[uint32(tokenId)].styleCID;
    require((bytes(metadataCID).length > 0), 'no CID stored');
    return _metadataURI(metadataCID);
  }

  function quoteFee(IERC721 nft, uint32 style_token_id)
    external
    view
    returns (uint256 fee)
  {
    fee = styleSettings[style_token_id].priceStrategy.quote(
      this,
      nft,
      style_token_id,
      styleSettings[style_token_id]
    );
  }

  function getSettings(uint32 style_token_id)
    public
    view
    returns (StyleSettings memory)
  {
    return styleSettings[style_token_id];
  }

  function isSaleActive(uint32 style_token_id) public view returns (bool) {
    return styleSettings[style_token_id].salesIsActive;
  }

  //todo: ensure that this returns 0 when no allowlist exists
  function reservedTokens(uint32 style_token_id) public view returns (uint32) {
    if (block.timestamp > allowlists[style_token_id].reservedUntil) {
      //reservation period has ended
      return 0;
    }
    return allowlists[style_token_id].numReserved;
  }

  function availableForPublicMinting(uint32 style_token_id)
    public
    view
    returns (uint32)
  {
    return
      styleSettings[style_token_id].cap -
      styleSettings[style_token_id].mintedOfStyle -
      reservedTokens(style_token_id);
  }

  //todo restrict visibility to internal onlySplice
  function verifyAllowlistEntryProof(
    uint32 style_token_id,
    bytes32[] memory allowlistProof,
    address requestor
  ) public view returns (bool) {
    return
      MerkleProof.verify(
        allowlistProof,
        allowlists[style_token_id].merkleRoot,
        //or maybe: https://ethereum.stackexchange.com/questions/884/how-to-convert-an-address-to-bytes-in-solidity/41356
        keccak256(abi.encode(requestor))
      );
  }

  function decreaseAllowance(uint32 style_token_id, address requestor)
    public
    nonReentrant
    onlySplice
  {
    // CHECKS
    if (
      mintsAlreadyAllowed[style_token_id][requestor] + 1 >
      allowlists[style_token_id].mintsPerAddress
    ) {
      revert PersonalReservationLimitExceeded(style_token_id);
    }

    if (allowlists[style_token_id].numReserved < 1) {
      revert NotEnoughTokensToMatchReservation(style_token_id);
    }
    // INTERACTIONS
    allowlists[style_token_id].numReserved -= 1;
    mintsAlreadyAllowed[style_token_id][requestor] =
      mintsAlreadyAllowed[style_token_id][requestor] +
      1;
  }

  function mintsLeft(uint32 style_token_id) public view returns (uint32) {
    return
      styleSettings[style_token_id].cap -
      styleSettings[style_token_id].mintedOfStyle;
  }

  //todo: IMPORTANT check that this really can only be called by the Splice contract!
  //https://ethereum.org/de/developers/tutorials/interact-with-other-contracts-from-solidity/
  //https://medium.com/@houzier.saurav/calling-functions-of-other-contracts-on-solidity-9c80eed05e0f
  function incrementMintedPerStyle(uint32 style_token_id)
    external
    onlySplice
    returns (uint32)
  {
    if (!isSaleActive(style_token_id)) {
      revert SaleNotActive(style_token_id);
    }

    if (mintsLeft(style_token_id) == 0) {
      revert MintingCapOnStyleReached();
    }
    styleSettings[style_token_id].mintedOfStyle += 1;
    return styleSettings[style_token_id].mintedOfStyle;
  }

  function addAllowlist(
    uint32 style_token_id,
    uint32 _numReserved,
    uint8 _mintsPerAddress,
    bytes32 _merkleRoot,
    uint64 _reservedUntil
  ) external onlyArtist {
    //todo: should only be possible when not minted yet?

    //CHECKS
    uint32 cap = styleSettings[style_token_id].cap;
    if (_numReserved >= cap || _mintsPerAddress > cap) {
      revert BadReservationParameters(_numReserved, cap);
    }
    if (_reservedUntil < block.timestamp + 1 days)
      revert AllowlistDurationTooShort(_reservedUntil);

    //INTERACTION
    allowlists[style_token_id] = Allowlist({
      numReserved: _numReserved,
      merkleRoot: _merkleRoot,
      reservedUntil: _reservedUntil,
      mintsPerAddress: _mintsPerAddress
    });
  }

  function mint(
    uint32 _cap,
    string memory _metadataCID,
    ISplicePriceStrategy _priceStrategy,
    bytes32 _priceStrategyParameters,
    bool _salesIsActive
  ) external onlyArtist returns (uint32 style_token_id) {
    //EFFECTS
    _styleTokenIds.increment();
    style_token_id = _styleTokenIds.current().toUint32();

    styleSettings[style_token_id] = StyleSettings({
      cap: _cap,
      styleCID: _metadataCID,
      priceStrategy: _priceStrategy,
      priceParameters: _priceStrategyParameters,
      mintedOfStyle: 0,
      salesIsActive: _salesIsActive
    });

    //INTERACTIONS
    _safeMint(msg.sender, style_token_id);
  }
}
