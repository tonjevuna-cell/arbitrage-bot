require("dotenv").config();
const { ethers } = require("ethers");
const config = require("./config.json");
const { getFlashloanAmount, estimateProfit, executeArbitrageTrade } = require("./helper");

let gasReserve = 0;
let firstTradeDone = false;

async function main() {
  console.log("[BOT] Starting arbitrage bot...");
  const provider = new ethers.WebSocketProvider(`wss://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`);

  provider.on("block", async (blockNumber) => {
    try {
      const flashLoanUSD = await getFlashloanAmount();
      if (!flashLoanUSD) return;

      const { profit, estimatedGas } = await estimateProfit(flashLoanUSD);
      if (profit <= 0) return;

      let multiplier = getDynamicMultiplier(flashLoanUSD);
      const maxGasAllowed = firstTradeDone ? gasReserve * multiplier : parseFloat(process.env.INITIAL_GAS_FUNDS);

      if (estimatedGas > maxGasAllowed) {
        console.log(`[SKIP] Estimated gas ${estimatedGas} exceeds allowed ${maxGasAllowed}`);
        return;
      }

      const netProfit = await executeArbitrageTrade(flashLoanUSD, profit);

      if (netProfit > 0) {
        firstTradeDone = true;
        gasReserve = gasReserve - estimatedGas + netProfit;
        console.log(`[SUCCESS] Profit: $${netProfit.toFixed(2)}, Gas reserve: $${gasReserve.toFixed(2)}`);
      }
    } catch (err) {
      console.error("[ERROR]", err);
    }
  });
}

function getDynamicMultiplier(flashLoanUSD) {
  const thresholds = config.LOAN_SIZE_THRESHOLDS;
  const multipliers = config.GAS_MULTIPLIERS_BY_LOAN;
  for (let i = thresholds.length - 1; i >= 0; i--) {
    if (flashLoanUSD >= thresholds[i]) return multipliers[i];
  }
  return multipliers[0];
}

main().then(() => console.log("[BOT] Running...")).catch(console.error);
