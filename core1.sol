pragma solidity ^0.4.25;

contract SafeMath {
    function safeAdd(uint a, uint b) public pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function safeSub(uint a, uint b) public pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function safeMul(uint a, uint b) public pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function safeDiv(uint a, uint b) public pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

contract SemadaCore is SafeMath {

    uint256 public proposalIndex;

    constructor() public {
      proposalIndex = 1;
    }

    mapping(string => address) erc20SymbolAddresses;

    struct Vote {
      address from;
      uint256 rep;
      bool vote;
    }

    struct Pool { 
      address from;  
      string tokenSymbol;
      string name; 
      uint256 timeout;  
      string evidence;  
      Vote[] votes;
    }

    mapping(uint256 => Pool) validationPool;

    function getProposal(uint256 _proposalIndex) view public returns (address, string, string, uint256, string) {
      return (validationPool[_proposalIndex].from, validationPool[_proposalIndex].tokenSymbol, validationPool[_proposalIndex].name, validationPool[_proposalIndex].timeout, validationPool[_proposalIndex].evidence);
    }


  function vote(uint256 _proposalIndex, address _from, uint256 _rep, bool _vote)  public payable {
    Pool storage pool = validationPool[_proposalIndex];
    if (now < pool.timeout) {
      Vote memory voteIns = Vote({from:_from, rep:_rep, vote:_vote});
      pool.votes.push(voteIns);
    }
  }

  function vote(uint256 _proposalIndex, bool _vote)  public payable {
    Pool storage pool = validationPool[_proposalIndex];
    if (now < pool.timeout) {
      Vote memory voteIns = Vote({from:msg.sender, rep:msg.value, vote:_vote});
      pool.votes.push(voteIns);
      REP rep = REP(erc20SymbolAddresses[pool.tokenSymbol]);
      rep.transfer(this, msg.value);
    }
  }

    function newProposal(string _tokenSymbol, string _tokenName, string _name, string _evidence) public payable{
        address _tokenAddress;
        if (erc20SymbolAddresses[_tokenSymbol] == 0x0){
          _tokenAddress = new REP(_tokenSymbol, _tokenName);
          erc20SymbolAddresses[_tokenSymbol] = _tokenAddress;
        } else {
          _tokenAddress = erc20SymbolAddresses[_tokenSymbol];
        }
        proposalIndex = safeAdd(proposalIndex, 1);

        REP rep = REP(_tokenAddress);
        rep.mintToken.value(msg.value);
        rep.transfer(this, msg.value);
        
        

        //setting timeout t0 180 seconds
        Pool storage pool = validationPool[proposalIndex];
        pool.from = msg.sender;
        pool.name = _name;
        pool.timeout = now + 180;
        pool.evidence = _evidence;

        vote(proposalIndex, msg.sender, msg.value/2, true);
        vote(proposalIndex, 0, msg.value/2, false);
    }

    function checkVote(uint256 _proposalIndex) public {
        Pool memory pool = validationPool[_proposalIndex];
        address tokenAddress;
        if(now >= pool.timeout){
            tokenAddress = erc20SymbolAddresses[pool.tokenSymbol];
            uint totalRep;
            uint totalYesRep;
            Vote[] memory votes = pool.votes;
            for(uint i = 0; i < votes.length; i++){
              totalRep = safeAdd(totalRep, votes[i].rep);
              if(votes[i].vote){
                totalYesRep = safeAdd(totalYesRep, votes[i].rep);
              }
            }
            bool winningVote;
            if(totalYesRep >= safeDiv(totalRep, 2)){
              winningVote = true;
            }
            REP rep = REP(tokenAddress);
            for(uint j = 0; j < votes.length; j++){
                uint256 betAmtWon;
              if(winningVote && votes[j].vote){
                betAmtWon = safeMul(votes[j].rep, safeDiv(totalRep, totalYesRep));
                rep.transferFrom(this, votes[j].from, betAmtWon);
              } else if (!winningVote && !votes[j].vote){
                betAmtWon = safeMul(votes[j].rep, safeDiv(totalRep, safeSub(totalRep,totalYesRep)));
                rep.transferFrom(this, votes[j].from, betAmtWon);
              }
            }
        }
    }
}


contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}


contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract REP is ERC20Interface, Owned, SafeMath {
    string public symbol;
    string public  name;
    uint8 public decimals;
    uint public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    constructor(string _tokenSymbol, string _name) public payable{
        symbol = _tokenSymbol;
        name = _name;
        decimals = 18;
        _totalSupply = msg.value;
        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public constant returns (uint) {
        return _totalSupply  - balances[address(0)];
    }

    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        return balances[tokenOwner];
    }

    function mintToken() public payable {
        balances[msg.sender] = safeAdd(balances[msg.sender], msg.value);
        _totalSupply = safeAdd(_totalSupply, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = safeSub(balances[msg.sender], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = safeSub(balances[from], tokens);
        allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(from, to, tokens);
        return true;
    }


    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }

    // Don't accept ETH
    function () public payable {
        revert();
    }

    // Owner can transfer out any accidentally sent ERC20 tokens
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}
