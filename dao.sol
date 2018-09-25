pragma solidity ^0.4.24;

// Semada DAO demo.

import "https://github.com/semadaio/openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";



/**
 * @title SEM Token
 * @dev A mintable ERC20 token. Intended to be used for a POC / demo. Can mint, can burn.
 */
contract SEM_mintable is MintableToken {

  string public constant name = "SEM Token";
  string public constant symbol = "SEM";
  uint8 public constant decimals = 18;

/**
   * @note 1B initial supply
   */

  uint256 public constant INITIAL_SUPPLY = 1000000000 * (10 ** uint256(decimals));

  /**
   * @dev Constructor that gives msg.sender all of existing tokens.
   */
  constructor() public {
    totalSupply_ = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
    emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
  }

}

contract owned {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}



/**
 * The SEM holder DAO contract
 */
contract SEM_DAO_DEMO is owned, SEM_mintable {


    uint public numberOfTokensToMintPerNewProposal = 1000; // default amount.
    uint public debatingPeriodInMinutes;
    Proposal[] public proposals;
    uint public numProposals;



    event ProposalAdded(uint proposalID, address recipient, uint amount, string description);
    event Voted(uint proposalID, bool position, address voter);
    event Staked(uint proposalID, uint numOfStakes, address voter);
    event ProposalTallied(uint proposalID, uint result, bool active);
    event ChangeOfRules(uint newDebatingPeriodInMinutes);

    struct Proposal {
        address recipient;
        uint amount;
        string description;
        uint minExecutionDate;
        bool executed;
        bool proposalPassed;
        uint numberOfVotes;
        
        bytes32 proposalHash;
        Vote[] votes;
       
        mapping (address => bool) voted;
    }

    struct Vote {
        bool inSupport;
        address voter;
        uint stakes;
    }
    
     



    /**
     * Constructor function
     *
     * First time setup
     */
    constructor(uint minutesForDebate) payable public {
        changeVotingRules(minutesForDebate);
    }

    /**
     * Change voting rules
     *
     * Make so that proposals need to be discussed for at least `minutesForDebate/60` hours
     *
     * @param minutesForDebate the minimum amount of delay between when a proposal is made and when it can be executed
     */
    function changeVotingRules(uint minutesForDebate) onlyOwner public {
    
        debatingPeriodInMinutes = minutesForDebate;
        emit ChangeOfRules(debatingPeriodInMinutes);
    }

    /**
     * Add Proposal
     *
     * Submit Proposal for a vote. Fee (proposalFee / 1e18) detrmines how many tokens are minted. 
     *
     * @param beneficiary who to send the SEM tokens to if proposal is approved
     * @param proposalFee is the fee paid to submit proposal. It determines how many tokens will be minted.
     * @param ProposalURL - A URL of the proposal.
     */
    function newProposal(
        address beneficiary,
        uint proposalFee,
        string ProposalURL
       
    )
        public
        returns (uint proposalID)
    {
        proposalID = proposals.length++;
        Proposal storage p = proposals[proposalID];
        p.recipient = beneficiary;
        p.amount = proposalFee;
        p.description = ProposalURL;
        //p.proposalHash = keccak256(abi.encodePacked(beneficiary, proposalFee));
        p.proposalHash = keccak256(abi.encodePacked(p.description, proposalFee));
        
        //p.minExecutionDate = now + debatingPeriodInMinutes * 1 minutes;
        p.minExecutionDate = now + 10 * 1 minutes;
        p.executed = false;
        p.proposalPassed = false;
        p.numberOfVotes = 0;
        
        emit ProposalAdded(proposalID, beneficiary, proposalFee, ProposalURL);
        
        numProposals = SafeMath.add(proposalID,1);
        
        //mint SEM tokens, number is based on proposal fee amount
        numberOfTokensToMintPerNewProposal = SafeMath.mul(proposalFee, 10);
        mint (owner, numberOfTokensToMintPerNewProposal);
        

        return proposalID;
    }

   
  



    /**
     * Log a vote for a proposal
     *
     * Vote `supportsProposal? in support of : against` proposal #`proposalNumber`
     *
     * @param proposalNumber number of proposal
     * @param supportsProposal either in favor or against it
     */
    function vote(
        uint proposalNumber,
        bool supportsProposal,
        uint NumberOfREPs
    )
        public
        returns (uint voteID)
    {
        Proposal storage p = proposals[proposalNumber];
        require(p.voted[msg.sender] != true);

        voteID = p.votes.length++;
        p.votes[voteID] = Vote({inSupport: supportsProposal, voter: msg.sender, stakes: NumberOfREPs});
        p.voted[msg.sender] = true;
        p.numberOfVotes = voteID +1;
        
        // Transfer tokens to betting pool - can be triggered by dapp after the voting is finalized. 
        // DAO members approve token transfers when they join the DAO.
        
        
        emit Voted(proposalNumber,  supportsProposal, msg.sender);
        //emit Staked(proposalNumber, NumberOfREPs, msg.sender);
        return voteID;
    }

    /**
     * Finish vote
     *
     * Count the votes proposal #`proposalNumber` and execute it if approved
     *
     * @param proposalNumber proposal number
    */
    function executeProposal(uint proposalNumber) public {
        Proposal storage p = proposals[proposalNumber];
        //Commented out for DEMO purposes:
        //require(now > p.minExecutionDate                                             // If it is past the voting deadline
            //&& !p.executed                                                          // and it has not already been executed
            //&& p.proposalHash == keccak256(abi.encodePacked(p.recipient, p.amount))); // and the supplied code matches the proposal...


        // tally the results
     
        uint yea = 0;
        uint nay = 0;

        for (uint i = 0; i <  p.votes.length; ++i) {
            Vote storage v = p.votes[i];
            
            
            //calculate weight based on REP stakes
            uint voteWeight = v.stakes;
            
            
            if (v.inSupport) {
                yea += voteWeight;
            } else {
                nay += voteWeight;
            }
        }

       

        if (yea > nay ) {
            // Proposal passed; execute the transaction

            p.executed = true;
/*
The more you stake the more you win. Each person's winnings, W, are calculated by taking the number that person staked, S, divided by the total staked by everyone who participated, T, and multiply that by the total lost, L (which is the sum of all the REP staked against the winners).

So we get
W = (S / T)*L
where
T = S[1] + S[2] + ... + S[N]
where S[i] is the stake for member i who voted correctly (including the 1/2 of the newly minted tokens voted on the winning side)
and
L = L[1] + L[2] + ... + L[N]
where L[i] is the stake for member  i  who voted incorrectly (including the 1/2 of the newly minted tokens voted on the losing side).        
*/         
			
			//OP gets 50% of newly minted tokens
			//Upvoters get the other 50% of the newly minted tokens
			//Upvoters get the downvoter's SEM tokens
			
			//Fee paid in ethereum for the proposal submission is distributed as salaries between experts (this can be triggered by dApp)

            p.proposalPassed = true;
        } else {
            // Proposal failed
			//Downvoters get the 50% of OP's stakes, and the other half is burnt
            p.proposalPassed = false;
			
        }

        // Fire Events
        emit ProposalTallied(proposalNumber, yea - nay, p.proposalPassed);
    }
}
