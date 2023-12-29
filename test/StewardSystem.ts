import { ethers } from 'hardhat';
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";

describe("StewardSystem", function () {
    const enum Vote {
        Abstain,
        Approve,
        Reject
    }

    const enum StewardStatus {
        NotExist,
        Valid,
        Expired
    }

    const enum StewardAction {
        Set,
        Remove
    }

    async function deployStewardSystemFixture() {
        const accounts = await ethers.getSigners();
        const ownerAddress = await accounts[0].getAddress();

        // Steward addresses (last one is expired)
        const stewardAddresses = [ownerAddress, await accounts[1].getAddress(), await accounts[2].getAddress(), await accounts[3].getAddress()];
        const stewardExpireTimstamps = [Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER, 1703745085];

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
            expect((await stewardSystem.getSteward(e))[1]).to.equal(stewardExpireTimstamps[stewardAddresses.indexOf(e)]);
        });
    });

    it("Stwards should be able to propose a new steward, vote for 5 seconds (5), and execute proposal", async function () {
        const { stewardSystem, accounts } = await loadFixture(deployStewardSystemFixture);

        const newProposalVoteDuration = 5; // 5 seconds
        await stewardSystem.connect(accounts[0]).setStewardVoteDuration(newProposalVoteDuration);
        expect(await stewardSystem.proposalVoteDuration()).to.equal(newProposalVoteDuration);

        const stewardAction = BigInt(StewardAction.Set); // (uint256) -> (bigint) 0n = set steward
        const targetAddress = "0x0000000000000000000000000000000000000001";
        const newExpireTimestamp = 1706135485n; // (uint256) -> (bigint)

        await stewardSystem.connect(accounts[0]).proposeSteward(stewardAction, targetAddress, newExpireTimestamp);

        // console.log("------------------");
        // const stewards = await stewardSystem.getStewards();
        // console.log("Stewards: ");
        // for (let i = 0; i < stewards.length; i++) {
        //     console.log(stewards[i]);
        //     console.log(await stewardSystem.getSteward(stewards[i]));
        //     console.log();
        // }
        // console.log("------------------");

        const filter = stewardSystem.filters.StewardProposalCreated;
        const events = await stewardSystem.queryFilter(filter, "latest", "latest");
        const proposalId = events[0].args[0];
        const votingEndTimestampEvent = events[0].args[4];

        let proposal = await stewardSystem.getStewardProposalById(proposalId);

        expect(proposal[0]).to.eql(stewardAction);
        expect(proposal[1]).to.eql(targetAddress);
        expect(proposal[2]).to.eql(newExpireTimestamp);
        expect(proposal[3]).to.eql(votingEndTimestampEvent);
        for (let i = 0; i < events[0].args[5].length; i++) {
            expect(proposal[4][i]).to.eql(events[0].args[5][i]);
        }

        await stewardSystem.connect(accounts[0]).voteOnStewardProposal(proposalId, Vote.Approve);
        await stewardSystem.connect(accounts[1]).voteOnStewardProposal(proposalId, Vote.Approve);
        await stewardSystem.connect(accounts[2]).voteOnStewardProposal(proposalId, Vote.Approve);
        await time.increase(6);
        await expect(stewardSystem.connect(accounts[2]).voteOnStewardProposal(proposalId, Vote.Approve)).to.be.revertedWith("Voting has ended");

        proposal = await stewardSystem.getStewardProposalById(proposalId);

        // console.log("------------------");
        // console.log("Proposal Voters & Votes: ");
        // for (let i = 0; i < proposal[5].length; i++) {
        //     console.log(proposal[4][i]);
        //     console.log(proposal[5][i]);
        //     console.log();
        // }
        // console.log("------------------");

        proposal[5].forEach(e => {
            expect(e).to.equal(BigInt(Vote.Approve));
        });

        await stewardSystem.connect(accounts[0]).executeStewardProposal(proposalId);
        await expect(stewardSystem.connect(accounts[0]).executeStewardProposal(proposalId)).to.be.revertedWith("Already executed");
    });
})
