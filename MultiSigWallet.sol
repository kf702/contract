pragma solidity ^0.4.7;

contract MultiSigWallet {
    address private owner;
    mapping(address => uint8) private managers;

    modifier isOwner() {
        require(owner == msg.sender);
        _;
    }

    modifier isManager() {
        require(msg.sender == owner || managers[msg.sender] == 1);
        _;
    }

    uint256 constant MIN_SIGNATURES = 3;
    uint256 private transactionIdx;

    struct Transaction {
        address from;
        address to;
        uint256 amount;
        uint8 signatureCount;
        mapping(address => uint8) signatures;
    }

    mapping(uint256 => Transaction) private transactions;
    uint256[] private pendingTransactions;

    constructor() public {
        owner = msg.sender;
    }

    event DepositFunds(address from, uint256 amount);
    event TransferFunds(address to, uint256 amount);
    event TransactionCreated(
        address from,
        address to,
        uint256 amount,
        uint256 transactionId
    );

    function addManager(address manager) public isOwner {
        managers[manager] = 1;
    }

    function removeManager(address manager) public isOwner {
        managers[manager] = 0;
    }

    function() public payable {
        emit DepositFunds(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public isManager {
        transferTo(msg.sender, amount);
    }

    function transferTo(address to, uint256 amount) public isManager {
        require(address(this).balance >= amount);
        uint256 transactionId = transactionIdx++;

        Transaction memory transaction;
        transaction.from = msg.sender;
        transaction.to = to;
        transaction.amount = amount;
        transaction.signatureCount = 0;
        transactions[transactionId] = transaction;
        pendingTransactions.push(transactionId);
        emit TransactionCreated(msg.sender, to, amount, transactionId);
    }

    function getPendingTransactions()
        public
        view
        isManager
        returns (uint256[])
    {
        return pendingTransactions;
    }

    function signTransaction(uint256 transactionId) public isManager {
        Transaction storage transaction = transactions[transactionId];
        require(0x0 != transaction.from);
        require(msg.sender != transaction.from);
        require(transaction.signatures[msg.sender] != 1);
        transaction.signatures[msg.sender] = 1;
        transaction.signatureCount++;

        if (transaction.signatureCount >= MIN_SIGNATURES) {
            require(address(this).balance >= transaction.amount);
            transaction.to.transfer(transaction.amount);
            emit TransferFunds(transaction.to, transaction.amount);
            deleteTransactions(transactionId);
        }
    }

    function deleteTransactions(uint256 transacionId) public isManager {
        uint8 replace = 0;
        for (uint256 i = 0; i < pendingTransactions.length; i++) {
            if (1 == replace) {
                pendingTransactions[i - 1] = pendingTransactions[i];
            } else if (transacionId == pendingTransactions[i]) {
                replace = 1;
            }
        }
        delete pendingTransactions[pendingTransactions.length - 1];
        pendingTransactions.length--;
        delete transactions[transacionId];
    }

    function walletBalance() public view isManager returns (uint256) {
        return address(this).balance;
    }
}
