const { createTypeData, signTypedData } = require("./EIP712");


const Types = {
	TransferMedals: [
        { name: 'signer', type: 'address' },
        { name: 'sender', type: 'address' },
        { name: 'tokenId', type: 'uint256' },
        { name: 'value', type: 'uint256' },
        { name: 'transactionHash', type: 'bytes32' }
    ]
};

async function sign(signer, sender, tokenId, value, transactionHash, verifyingContract) {
	const chainId = 1;
	const data = createTypeData({
		name: "ChampionNFT",
		chainId,
		version: "1.0",
		verifyingContract
	}, 'TransferMedals', { signer, sender, tokenId, value, transactionHash}, Types);
	return (await signTypedData(web3, signer, data)).sig;
}

module.exports = { sign }