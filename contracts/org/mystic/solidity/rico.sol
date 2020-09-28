/*
 ██████╗ ██████╗ ███████╗██████╗  █████╗ ████████╗██╗███╗   ██╗ ██████╗        
██╔═══██╗██╔══██╗██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██║████╗  ██║██╔════╝        
██║   ██║██████╔╝█████╗  ██████╔╝███████║   ██║   ██║██╔██╗ ██║██║  ███╗       
██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██╔══██║   ██║   ██║██║╚██╗██║██║   ██║       
╚██████╔╝██║     ███████╗██║  ██║██║  ██║   ██║   ██║██║ ╚████║╚██████╔╝       
 ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝╚═╝  ╚═══╝ ╚═════╝        
                                                                               
 █████╗  ██████╗ ██████╗ ███████╗███████╗███╗   ███╗███████╗███╗   ██╗████████╗
██╔══██╗██╔════╝ ██╔══██╗██╔════╝██╔════╝████╗ ████║██╔════╝████╗  ██║╚══██╔══╝
███████║██║  ███╗██████╔╝█████╗  █████╗  ██╔████╔██║█████╗  ██╔██╗ ██║   ██║   
██╔══██║██║   ██║██╔══██╗██╔══╝  ██╔══╝  ██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║   
██║  ██║╚██████╔╝██║  ██║███████╗███████╗██║ ╚═╝ ██║███████╗██║ ╚████║   ██║   
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   
|| <🏛️> Ricardian Co. Operating Agreement (RCOA) <🏛️> ||
DEAR MSG.SENDER(S):
/ RCOA is a project in beta.
// Please audit and use at your own risk.
/// Entry into RCOA shall not create an attorney/client relationship.
//// Likewise, RCOA should not be construed as legal advice or replacement for professional counsel.
///// STEAL THIS C0D3SL4W
~presented by Open, ESQ || lexDAO LLC
*/

pragma solidity 0.5.17;

contract BasicNFT { // based on GAMMA nft - 0xeF0ff94B152C00ED4620b149eE934f2F4A526387
    address public manager;
    uint256 public totalSupply;
    uint256 public constant totalSupplyCap = 100000000000000000000;
    string public name = "Ricardian LLC, Series";
    string public symbol = "RICO";
    
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => uint256) public tokenByIndex;
    mapping(uint256 => string) public tokenURI;
    mapping(bytes4 => bool) public supportsInterface; // eip-165 
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => mapping(uint256 => uint256)) public tokenOfOwnerByIndex;
    
    event Approval(address indexed approver, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed holder, address indexed operator, bool approved);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor () internal {
        manager = msg.sender;
        supportsInterface[0x80ac58cd] = true; // ERC721 
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
    }
    
    function approve(address spender, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/operator");
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId); 
    }
    
    function mint(address to) external { 
        require(msg.sender == manager, "!mystic");
        totalSupply++;
        require(totalSupply <= totalSupplyCap, "capped");
        uint256 tokenId = totalSupply;
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        tokenByIndex[tokenId - 1] = tokenId;
        tokenURI[tokenId] = "https://ipfs.globalupload.io/QmVhscFUL3MiRqpPNwLBVoiSYrVAqcMGvGLEeFysKGAsbu";
        tokenOfOwnerByIndex[to][tokenId - 1] = tokenId;
        emit Transfer(address(0), to, tokenId); 
    }
    
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function _transfer(address from, address to, uint256 tokenId) internal {
        balanceOf[from]--; 
        balanceOf[to]++; 
        getApproved[tokenId] = address(0);
        ownerOf[tokenId] = to;
        tokenOfOwnerByIndex[from][tokenId - 1] = 0;
        tokenOfOwnerByIndex[to][tokenId - 1] = tokenId;
        emit Transfer(from, to, tokenId); 
    }
    
    function transfer(address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId], "!owner");
        _transfer(msg.sender, to, tokenId);
    }
    
    function transferBatch(address[] calldata to, uint256[] calldata tokenId) external {
        require(to.length == tokenId.length, "!to/tokenId");
        for (uint256 i = 0; i < to.length; i++) {
            require(msg.sender == ownerOf[tokenId[i]], "!owner");
            _transfer(msg.sender, to[i], tokenId[i]);
        }
    }
    
    function transferFrom(address from, address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || getApproved[tokenId] == msg.sender || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/spender/operator");
        _transfer(from, to, tokenId);
    }
}

contract OperatingAgreement {
    address payable public lexDAO;
    uint256 public signatureFee;
    uint256 public upgradeFee;
    uint256 public version;
    string public terms;
    // signature tracking: 
    uint256 public signature;
    mapping(uint256 => Signature) public sigs;

    struct Signature {
        address signatory;
        uint256 version;
        string details;
        string terms;
    }

    event Amend(uint256 indexed version, string indexed terms);
    event Sign(address indexed signatory, uint256 indexed number, string indexed details);
    event Upgrade(address indexed signatory, uint256 indexed number, string indexed details);
    event UpdateLexDAO(address indexed lexDAO, string indexed details);

    constructor(address payable _lexDAO, uint256 _filingFee, uint256 _sigFee, bytes32 memory _terms) public {
        lexDAO = _lexDAO;
        filingFee = _filingFee;
        sigFee = _sigFee;
        terms = _terms;
    }

    /******************
    SMART CO. FUNCTIONS
    ******************/
    function sign(string calldata details) payable external {
        require(msg.value == sigFee);
	    signatures++;

        sigs[signatures] = Signature(
                msg.sender,
                version,
                terms,
                details,
                false);

        (bool success, ) = lexDAO.call.value(msg.value)("");
        require(success, "!transfer");

        emit Sign(msg.sender, number, details);
    }

    function upgrade(uint256 number, string calldata details) payable external {
        Signature storage sig = sigs[number];
        require(msg.sender == sig.signatory);
        require(msg.value == sigFee);

        sig.version = version;
        sig.terms = terms;
        sig.details = details;

        (bool success, ) = lexDAO.call.value(msg.value)("");
        require(success, "!transfer");

        emit Upgrade(msg.sender, number, details);
    }

    /***************
    LEXDAO FUNCTIONS
    ***************/
    modifier onlyLexDAO() {
        require(msg.sender == lexDAO, "!lexDAO");
        _;
    }

    function amendTerms(string memory _terms) external onlyLexDAO {
        version++;
        terms = _terms;

        emit Amend(version, terms);
    }

    function updateFee(uint256 _signatureFee, uint256 _upgradeFee) external onlyLexDAO {
        signatureFee = _signatureFee;
        upgradeFee = _upgradeFee;
    }

    function updateLexDAO(address payable _lexDAO, string calldata details) external onlyLexDAO {
        lexDAO = _lexDAO;
        emit UpdateLexDAO(lexDAO, details);
    }
}
