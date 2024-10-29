// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;
/*
使用 EIP2612 标准（可基于 Openzepplin 库）编写一个自己名称的 Token 合约。
修改 TokenBank 存款合约 ,添加一个函数 permitDeposit 以支持离线签名授权（permit）进行存款。
修改Token 购买 NFT NTFMarket 合约，添加功能 permitBuy() 实现只有离线授权的白名单地址才可以购买 NFT （用自己的名称发行 NFT，再上架） 。白名单具体实现逻辑为：项目方给白名单地址签名，白名单用户拿到签名信息后，传给 permitBuy() 函数，在permitBuy()中判断时候是经过许可的白名单用户，如果是，才可以进行后续购买，否则 revert 。

要求：
有 Token 存款及 NFT 购买成功的测试用例
有测试用例运行日志或截图，能够看到 Token 及 NFT 转移。
*/
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPermit2.sol";
import "./interfaces/ISignatureTransfer.sol";
// import "./interfaces/IAllowanceTransfer.sol";

contract TokenBank {
    address admin;
    IERC20 public token;

    bool private _reentrancyGuard;
    // The canonical permit2 contract.
    IPermit2 public immutable PERMIT2;

    mapping(address => uint) internal balances;

    constructor(address _token, address _permit) {
        admin = msg.sender;
        token = IERC20(_token);

        PERMIT2 = IPermit2(_permit);
    }

    // 提取函数：用户提取自己的 token，管理员可以提取所有 token
    function withdraw(uint256 amount) public {
        if (msg.sender == admin) {
            // 管理员提取所有的 token
            uint256 contractBalance = token.balanceOf(address(this));
            require(contractBalance > 0, "No tokens to withdraw");

            bool success = token.transfer(admin, contractBalance);
            require(success, "Admin withdraw failed");
        } else {
            // 普通用户提取自己存入的 token
            require(amount > 0, "Amount must be greater than 0");
            require(balances[msg.sender] >= amount, "Insufficient balance");

            // 更新用户余额
            balances[msg.sender] -= amount;

            // 转账给用户
            bool success = token.transfer(msg.sender, amount);
            require(success, "User withdraw failed");
        }
    }

    function deposit(uint256 amount) public {
        // 将用户的 token 转移到 TokenBank 合约中
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");

        // 记录用户的存款
        balances[msg.sender] += amount;
    }

    // Prevents reentrancy attacks via tokens with callback mechanisms.
    modifier nonReentrant() {
        require(!_reentrancyGuard, "no reentrancy");
        _reentrancyGuard = true;
        _;
        _reentrancyGuard = false;
    }

    function depositWithPermit2(
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant {
        // Transfer tokens from the caller to ourselves.
        PERMIT2.permitTransferFrom(
            // The permit message. Spender will be inferred as the caller (us).
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: address(token),
                    amount: amount
                }),
                nonce: nonce,
                deadline: deadline
            }),
            // The transfer recipient and amount.
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: amount
            }),
            // The owner of the tokens, which must also be
            // the signer of the message, otherwise this call
            // will fail.
            msg.sender,
            // The packed signature that was the result of signing
            // the EIP712 hash of `permit`.
            signature
        );

        deposit(amount);
    }
}
