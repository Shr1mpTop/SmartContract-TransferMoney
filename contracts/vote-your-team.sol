
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract CS2MajorFanConsensus {
    struct Team {
        uint256 id;
        string name;
        uint256 totalVoteAmount;
        uint256 supporterCount;
    }

    // 增加一个 Refunding 状态
    enum GameStatus { Open, Stopped, Finished, Refunding }

    address public owner;
    GameStatus public status;
    Team[] public teams;
    
    // 记录用户在某个战队的投票能量
    mapping(address => mapping(uint256 => uint256)) public userVotes;
    
    uint256 public totalRewardPool;
    uint256 public winningTeamId;
    uint256 public charityBalance;

    event NewVote(address indexed user, uint256 teamId, uint256 amount);
    event GameStatusChanged(GameStatus newStatus);
    event WinnerSelected(uint256 teamId, string teamName);
    event PrizeWithdrawn(address indexed user, uint256 amount);
    event Refunded(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only admin can do this");
        _;
    }

    constructor() {
        owner = msg.sender;
        status = GameStatus.Open;
    }

    // 1. 添加战队
    function addTeam(string memory _name) public onlyOwner {
        require(status == GameStatus.Open, "Cannot add team now");
        uint256 newId = teams.length;
        teams.push(Team(newId, _name, 0, 0));
    }

    // 2. 停止投票
    function stopVoting() public onlyOwner {
        status = GameStatus.Stopped;
        emit GameStatusChanged(status);
    }

    // 3. 选出冠军（核心修改逻辑）
    function selectWinner(uint256 _teamId) public onlyOwner {
        require(status == GameStatus.Stopped, "Game must be stopped first");
        require(_teamId < teams.length, "Invalid team ID");

        // 检查冠军队是否有投票额
        if (teams[_teamId].totalVoteAmount == 0) {
            // 特殊情况：没人投这个队，进入全员退款模式
            status = GameStatus.Refunding;
            // 退款模式下，不扣除公益金，大家原原本本拿回去
            charityBalance = 0; 
            emit GameStatusChanged(status);
            console.log("No votes on winner. Refund mode activated.");
        } else {
            // 正常情况
            status = GameStatus.Finished;
            winningTeamId = _teamId;

            uint256 charityAmount = (totalRewardPool * 10) / 100;
            charityBalance = charityAmount;
            
            emit WinnerSelected(_teamId, teams[_teamId].name);
            emit GameStatusChanged(status);
        }
    }


    function withdraw(uint256 _teamId) public {
        uint256 amount = userVotes[msg.sender][_teamId];
        require(amount > 0, "No balance to withdraw for this team");

        if (status == GameStatus.Refunding) {
            // --- 退款模式 ---
            // 无论你投的是谁，只要有积分，全额退回（不扣10%）
            
            // 1. 修改状态（防重入）
            userVotes[msg.sender][_teamId] = 0;
            
            // 2. 转账
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Refund failed");
            
            emit Refunded(msg.sender, amount);

        } else if (status == GameStatus.Finished) {
            // --- 正常发奖模式 ---
            // 只有投中冠军的人才能获取奖励
            require(_teamId == winningTeamId, "This team did not win");

            uint256 totalDistributableAmount = (totalRewardPool * 90) / 100;
            uint256 totalVoteOnWinner = teams[winningTeamId].totalVoteAmount;

            // 计算奖励积分
            uint256 payout = (amount * totalDistributableAmount) / totalVoteOnWinner;

            // 1. 修改状态
            userVotes[msg.sender][_teamId] = 0;

            // 2. 转账
            (bool success, ) = payable(msg.sender).call{value: payout}("");
            require(success, "Transfer failed");

            emit PrizeWithdrawn(msg.sender, payout);
            
        } else {
            revert("Game is not in withdrawal phase");
        }
    }

    // 5. 提取积分
    function withdrawCharity() public onlyOwner {
        require(status == GameStatus.Finished, "Game not finished");
        require(charityBalance > 0, "No charity funds");
        
        uint256 amount = charityBalance;
        charityBalance = 0;
        
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer failed");
    }

    // 投票
    function vote(uint256 _teamId) public payable {
        require(status == GameStatus.Open, "Voting is closed");
        require(_teamId < teams.length, "Invalid team");
        require(msg.value > 0, "Amount must be > 0");

        if (userVotes[msg.sender][_teamId] == 0) {
            teams[_teamId].supporterCount += 1;
        }

        userVotes[msg.sender][_teamId] += msg.value;
        teams[_teamId].totalVoteAmount += msg.value;
        totalRewardPool += msg.value;

        emit NewVote(msg.sender, _teamId, msg.value);
    }
    
    // View Helpers
    function getTeams() public view returns (Team[] memory) {
        return teams;
    }
}