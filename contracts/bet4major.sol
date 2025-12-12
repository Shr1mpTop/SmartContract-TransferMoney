// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract CS2MajorBetting {
    struct Team {
        uint256 id;
        string name;
        uint256 totalBetAmount;
        uint256 supporterCount;
    }

    // 增加一个 Refunding 状态
    enum GameStatus { Open, Stopped, Finished, Refunding }

    address public owner;
    GameStatus public status;
    Team[] public teams;
    
    // 记录用户在某个战队的下注金额
    mapping(address => mapping(uint256 => uint256)) public userBets;
    
    uint256 public totalPrizePool;
    uint256 public winningTeamId;
    uint256 public charityBalance;

    event NewBet(address indexed user, uint256 teamId, uint256 amount);
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

    // 2. 停止投注
    function stopBetting() public onlyOwner {
        status = GameStatus.Stopped;
        emit GameStatusChanged(status);
    }

    // 3. 选出冠军（核心修改逻辑）
    function selectWinner(uint256 _teamId) public onlyOwner {
        require(status == GameStatus.Stopped, "Game must be stopped first");
        require(_teamId < teams.length, "Invalid team ID");

        // 检查冠军队是否有下注额
        if (teams[_teamId].totalBetAmount == 0) {
            // 特殊情况：没人买这个队，进入全员退款模式
            status = GameStatus.Refunding;
            // 退款模式下，不扣除公益金，大家原原本本拿回去
            charityBalance = 0; 
            emit GameStatusChanged(status);
            console.log("No bets on winner. Refund mode activated.");
        } else {
            // 正常情况
            status = GameStatus.Finished;
            winningTeamId = _teamId;

            uint256 charityAmount = (totalPrizePool * 10) / 100;
            charityBalance = charityAmount;
            
            emit WinnerSelected(_teamId, teams[_teamId].name);
            emit GameStatusChanged(status);
        }
    }

    // 4. 用户提款/退款（核心修改逻辑）
    // 注意：这里需要传入 teamId，因为在退款模式下，用户可能需要取回输掉的队伍的钱
    function withdraw(uint256 _teamId) public {
        uint256 amount = userBets[msg.sender][_teamId];
        require(amount > 0, "No balance to withdraw for this team");

        if (status == GameStatus.Refunding) {
            // --- 退款模式 ---
            // 无论你投的是谁，只要有钱，全额退回（不扣10%）
            
            // 1. 修改状态（防重入）
            userBets[msg.sender][_teamId] = 0;
            
            // 2. 转账
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Refund failed");
            
            emit Refunded(msg.sender, amount);

        } else if (status == GameStatus.Finished) {
            // --- 正常发奖模式 ---
            // 只有投中冠军的人才能取钱
            require(_teamId == winningTeamId, "This team did not win");

            uint256 totalDistributableAmount = (totalPrizePool * 90) / 100;
            uint256 totalBetOnWinner = teams[winningTeamId].totalBetAmount;

            // 计算奖金
            uint256 payout = (amount * totalDistributableAmount) / totalBetOnWinner;

            // 1. 修改状态
            userBets[msg.sender][_teamId] = 0;

            // 2. 转账
            (bool success, ) = payable(msg.sender).call{value: payout}("");
            require(success, "Transfer failed");

            emit PrizeWithdrawn(msg.sender, payout);
            
        } else {
            revert("Game is not in withdrawal phase");
        }
    }

    // 5. 提取公益金
    function withdrawCharity() public onlyOwner {
        require(status == GameStatus.Finished, "Game not finished");
        require(charityBalance > 0, "No charity funds");
        
        uint256 amount = charityBalance;
        charityBalance = 0;
        
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer failed");
    }

    // 投注
    function bet(uint256 _teamId) public payable {
        require(status == GameStatus.Open, "Betting is closed");
        require(_teamId < teams.length, "Invalid team");
        require(msg.value > 0, "Amount must be > 0");

        if (userBets[msg.sender][_teamId] == 0) {
            teams[_teamId].supporterCount += 1;
        }

        userBets[msg.sender][_teamId] += msg.value;
        teams[_teamId].totalBetAmount += msg.value;
        totalPrizePool += msg.value;

        emit NewBet(msg.sender, _teamId, msg.value);
    }
    
    // View Helpers
    function getTeams() public view returns (Team[] memory) {
        return teams;
    }
}