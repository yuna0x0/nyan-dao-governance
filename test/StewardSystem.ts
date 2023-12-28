import { ethers } from 'hardhat';
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";

describe("StewardSystem", function () {
    async function deployStewardSystemFixture() {
        const accounts = await ethers.getSigners();
        const ownerAddress = await accounts[0].getAddress();

        const stewardAddresses = [ownerAddress, await accounts[1].getAddress(), await accounts[2].getAddress()];
        const stewardExpireTimstamps = [1706135485, 1706135485, 1703745085];
        const proposalVoteDuration = 86400; // 1 day

        const stewardSystem = await ethers.deployContract("StewardSystem", [stewardAddresses, stewardExpireTimstamps, proposalVoteDuration, ownerAddress]);
        await stewardSystem.waitForDeployment();

        return { stewardSystem, stewardAddresses, stewardExpireTimstamps, proposalVoteDuration, ownerAddress, accounts };
    }

    it("Should construct the right owner", async function () {
        const { stewardSystem, ownerAddress } = await loadFixture(deployStewardSystemFixture);
        expect(await stewardSystem.owner()).to.equal(ownerAddress);
    });

    it("Should construct the right proposalVoteDuration", async function () {
        const { stewardSystem, proposalVoteDuration } = await loadFixture(deployStewardSystemFixture);
        expect(await stewardSystem.proposalVoteDuration()).to.equal(proposalVoteDuration);
    });

    it("Should construct the right stewardAddresses", async function () {
        const { stewardSystem, stewardAddresses } = await loadFixture(deployStewardSystemFixture);
        expect(await stewardSystem.getStewards()).to.eql(stewardAddresses);
    });

    it("Should construct the right stewardExpireTimstamps", async function () {
        const { stewardSystem, stewardAddresses, stewardExpireTimstamps } = await loadFixture(deployStewardSystemFixture);
        stewardAddresses.forEach(async e => {
            expect(await stewardSystem.getStewardExpireTimestamp(e)).to.equal(stewardExpireTimstamps[stewardAddresses.indexOf(e)]);
        });
    });

    it("Stwards should be able to propose a new steward, vote for 5 seconds (5), and execute proposal", async function () {
        const { stewardSystem, accounts } = await loadFixture(deployStewardSystemFixture);

        const stewardAction = 0n; // (uint256) -> (bigint) 0 = set steward
        const targetAddress = "0x0000000000000000000000000000000000000001";
        const newExpireTimestamp = 1706135485n; // (uint256) -> (bigint)

        await stewardSystem.connect(accounts[0]).proposeSteward(stewardAction, targetAddress, newExpireTimestamp);

        const filter = stewardSystem.filters.StewardProposalCreated;
        const events = await stewardSystem.queryFilter(filter, "latest", "latest");
        const proposalId = events[0].args[0];
        const votingEndTimestampEvent = events[0].args[4];
        expect((await stewardSystem.getStewardProposalById(proposalId))[0]).to.eql(stewardAction);
        expect((await stewardSystem.getStewardProposalById(proposalId))[1]).to.eql(targetAddress);
        expect((await stewardSystem.getStewardProposalById(proposalId))[2]).to.eql(newExpireTimestamp);
        expect((await stewardSystem.getStewardProposalById(proposalId))[3]).to.eql(votingEndTimestampEvent);
        for (let i = 0; i < events[0].args[5].length; i++) {
            expect((await stewardSystem.getStewardProposalById(proposalId))[4][i]).to.eql(events[0].args[5][i]);
        }
    });
})
