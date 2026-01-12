// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import ERC20 interface & Ownable
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Interface for flashloan provider (example: Balancer or Aave)
interface IFlashLoanProvider {
    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}

// Interface for DEX Router (UniswapV3 / PancakeSwapV3 / Arbitrum DEX)
interface IRouter {
    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external returns (uint256 amountOut);
}

contract Arbitrage is Ownable {
    IFlashLoanProvider public flashLoanProvider;
    IRouter public router1;
    IRouter public router2;

    event TradeExecuted(address tokenIn, address tokenOut, uint256 profit);

    constructor(
        address _flashLoanProvider,
        address _router1,
        address _router2
    ) {
        flashLoanProvider = IFlashLoanProvider(_flashLoanProvider);
        router1 = IRouter(_router1);
        router2 = IRouter(_router2);
    }

    /**
     * @notice Owner triggers arbitrage
     * @param tokenIn Token to borrow
     * @param tokenOut Token to swap to
     * @param loanAmount Amount to borrow via flashloan
     * @param poolFee Fee tier for UniswapV3-like swaps
     */
    function executeArbitrage(
        address tokenIn,
        address tokenOut,
        uint256 loanAmount,
        uint24 poolFee
    ) external onlyOwner {
        // Encode data for callback
        bytes memory data = abi.encode(tokenIn, tokenOut, poolFee);

        // Request flashloan
        flashLoanProvider.flashLoan(address(this), tokenIn, loanAmount, data);
    }

    /**
     * @notice Flashloan callback
     * @dev Called by flashloan provider after funds are sent
     */
    function receiveFlashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external {
        require(msg.sender == address(flashLoanProvider), "Unauthorized");

        (address tokenIn, address tokenOut, uint24 fee) = abi.decode(
            data,
            (address, address, uint24)
        );

        // Approve router1 to spend tokenIn
        IERC20(tokenIn).approve(address(router1), amount);

        // Swap tokenIn → tokenOut on router1
        uint256 amountOut1 = router1.exactInputSingle(
            tokenIn,
            tokenOut,
            fee,
            address(this),
            amount,
            0
        );

        // Approve router2 to spend tokenOut
        IERC20(tokenOut).approve(address(router2), amountOut1);

        // Swap tokenOut → tokenIn on router2
        uint256 amountOut2 = router2.exactInputSingle(
            tokenOut,
            tokenIn,
            fee,
            address(this),
            amountOut1,
            0
        );

        // Repay flashloan
        require(amountOut2 >= amount, "Not enough to repay loan");
        IERC20(tokenIn).transfer(address(flashLoanProvider), amount);

        uint256 profit = amountOut2 - amount;
        emit TradeExecuted(tokenIn, tokenOut, profit);
    }

    /**
     * @notice Emergency withdrawal of any token
     */
    function withdrawToken(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner(), balance);
    }
}