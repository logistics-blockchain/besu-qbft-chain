const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DynamicMultiSigValidatorManager", function () {
  let contract;
  let admin1, admin2, admin3, admin4, admin5;
  let validator1, validator2, validator3, validator4;
  let candidate1, candidate2, candidate3;

  beforeEach(async function () {
    [admin1, admin2, admin3, admin4, admin5, validator1, validator2, validator3, validator4, candidate1, candidate2, candidate3] = await ethers.getSigners();

    const Contract = await ethers.getContractFactory("DynamicMultiSigValidatorManager");
    contract = await Contract.deploy(
      admin1.address,
      [validator1.address, validator2.address, validator3.address, validator4.address]
    );
  });

  describe("Deployment and Initialization", function () {
    it("should deploy with correct admin", async function () {
      expect(await contract.getAdminCount()).to.equal(1);
      expect(await contract.isAdmin(admin1.address)).to.be.true;
    });

    it("should have correct threshold on deployment", async function () {
      expect(await contract.getThreshold()).to.equal(1);
    });

    it("should deploy with correct initial validators", async function () {
      expect(await contract.getValidatorCount()).to.equal(4);
      const validators = await contract.getValidators();
      expect(validators).to.include(validator1.address);
      expect(validators).to.include(validator2.address);
      expect(validators).to.include(validator3.address);
      expect(validators).to.include(validator4.address);
    });

    it("should mark initial validators correctly", async function () {
      expect(await contract.isValidator(validator1.address)).to.be.true;
      expect(await contract.isValidator(validator2.address)).to.be.true;
      expect(await contract.isValidator(candidate1.address)).to.be.false;
    });
  });

  describe("Threshold Calculation", function () {
    it("should calculate threshold correctly for 1 admin", async function () {
      expect(await contract.getThreshold()).to.equal(1);
    });

    it("should calculate threshold correctly after adding admins", async function () {
      await contract.connect(admin1).proposeAddAdmin(admin2.address);
      expect(await contract.getThreshold()).to.equal(2);

      await contract.connect(admin1).proposeAddAdmin(admin3.address);
      await contract.connect(admin2).signAdminProposal(1);
      expect(await contract.getThreshold()).to.equal(2);

      await contract.connect(admin1).proposeAddAdmin(admin4.address);
      await contract.connect(admin2).signAdminProposal(2);
      expect(await contract.getThreshold()).to.equal(3);

      await contract.connect(admin1).proposeAddAdmin(admin5.address);
      await contract.connect(admin2).signAdminProposal(3);
      await contract.connect(admin3).signAdminProposal(3);
      expect(await contract.getThreshold()).to.equal(3);
    });
  });

  describe("Validator Application", function () {
    it("should allow candidate to submit application", async function () {
      await expect(
        contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com")
      ).to.emit(contract, "ApplicationSubmitted");

      const app = await contract.applications(candidate1.address);
      expect(app.isPending).to.be.true;
      expect(app.organization).to.equal("ACME Corp");
      expect(app.contactEmail).to.equal("test@acme.com");
    });

    it("should reject duplicate application", async function () {
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");

      await expect(
        contract.connect(candidate1).applyToBeValidator("ACME Corp 2", "test2@acme.com")
      ).to.be.revertedWith("Application pending");
    });

    it("should reject application from existing validator", async function () {
      await expect(
        contract.connect(validator1).applyToBeValidator("Validator Org", "val@test.com")
      ).to.be.revertedWith("Already validator");
    });
  });

  describe("Single Admin Validator Approval (1/1)", function () {
    beforeEach(async function () {
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");
    });

    it("should auto-execute approval with 1 admin", async function () {
      await expect(
        contract.connect(admin1).proposeApproval(candidate1.address, "Approved")
      ).to.emit(contract, "ValidatorApproved");

      expect(await contract.isValidator(candidate1.address)).to.be.true;
      const validators = await contract.getValidators();
      expect(validators).to.include(candidate1.address);
    });

    it("should clear application after approval", async function () {
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");

      const app = await contract.applications(candidate1.address);
      expect(app.isPending).to.be.false;
    });

    it("should reject approval without application", async function () {
      await expect(
        contract.connect(admin1).proposeApproval(candidate2.address, "Approved")
      ).to.be.revertedWith("No pending application");
    });
  });

  describe("Single Admin Validator Removal (1/1)", function () {
    beforeEach(async function () {
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");
    });

    it("should auto-execute removal with 1 admin", async function () {
      await expect(
        contract.connect(admin1).proposeRemoval(candidate1.address, "Removing")
      ).to.emit(contract, "ValidatorRemoved");

      expect(await contract.isValidator(candidate1.address)).to.be.false;
      const validators = await contract.getValidators();
      expect(validators).to.not.include(candidate1.address);
    });

    it("should reject removal of non-validator", async function () {
      await expect(
        contract.connect(admin1).proposeRemoval(candidate2.address, "Removing")
      ).to.be.revertedWith("Not a validator");
    });

    it("should reject removing last validator", async function () {
      await contract.connect(admin1).proposeRemoval(validator1.address, "Removing");
      await contract.connect(admin1).proposeRemoval(validator2.address, "Removing");
      await contract.connect(admin1).proposeRemoval(validator3.address, "Removing");
      await contract.connect(admin1).proposeRemoval(validator4.address, "Removing");

      await expect(
        contract.connect(admin1).proposeRemoval(candidate1.address, "Removing")
      ).to.be.revertedWith("Cannot remove last validator");
    });
  });

  describe("Adding Second Admin (1/1)", function () {
    it("should auto-execute admin addition with 1 admin", async function () {
      await expect(
        contract.connect(admin1).proposeAddAdmin(admin2.address)
      ).to.emit(contract, "AdminAdded");

      expect(await contract.getAdminCount()).to.equal(2);
      expect(await contract.isAdmin(admin2.address)).to.be.true;
      expect(await contract.getThreshold()).to.equal(2);
    });

    it("should reject adding existing admin", async function () {
      await expect(
        contract.connect(admin1).proposeAddAdmin(admin1.address)
      ).to.be.revertedWith("Already admin");
    });

    it("should reject adding zero address", async function () {
      await expect(
        contract.connect(admin1).proposeAddAdmin(ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid address");
    });
  });

  describe("Two Admin Validator Approval (2/2)", function () {
    beforeEach(async function () {
      await contract.connect(admin1).proposeAddAdmin(admin2.address);
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");
    });

    it("should require 2 signatures for approval", async function () {
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");

      expect(await contract.isValidator(candidate1.address)).to.be.false;

      const proposal = await contract.validatorProposals(0);
      const sigs = await contract.getValidatorProposalSignatures(0);
      expect(sigs.length).to.equal(1);
    });

    it("should execute after second signature", async function () {
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");

      await expect(
        contract.connect(admin2).signValidatorProposal(0)
      ).to.emit(contract, "ValidatorApproved");

      expect(await contract.isValidator(candidate1.address)).to.be.true;
    });

    it("should reject non-admin signing", async function () {
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");

      await expect(
        contract.connect(candidate2).signValidatorProposal(0)
      ).to.be.revertedWith("Only admin");
    });

    it("should reject double signing", async function () {
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");

      await expect(
        contract.connect(admin1).signValidatorProposal(0)
      ).to.be.revertedWith("Already signed");
    });
  });

  describe("Adding Third Admin (2/2)", function () {
    beforeEach(async function () {
      await contract.connect(admin1).proposeAddAdmin(admin2.address);
    });

    it("should require 2 signatures to add third admin", async function () {
      await contract.connect(admin1).proposeAddAdmin(admin3.address);
      expect(await contract.getAdminCount()).to.equal(2);

      await contract.connect(admin2).signAdminProposal(1);
      expect(await contract.getAdminCount()).to.equal(3);
      expect(await contract.getThreshold()).to.equal(2);
    });
  });

  describe("Three Admin Validator Approval (2/3)", function () {
    beforeEach(async function () {
      await contract.connect(admin1).proposeAddAdmin(admin2.address);
      await contract.connect(admin1).proposeAddAdmin(admin3.address);
      await contract.connect(admin2).signAdminProposal(1);
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");
    });

    it("should execute with 2 of 3 signatures", async function () {
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");

      await expect(
        contract.connect(admin3).signValidatorProposal(0)
      ).to.emit(contract, "ValidatorApproved");

      expect(await contract.isValidator(candidate1.address)).to.be.true;
    });

    it("should not require third signature", async function () {
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");
      await contract.connect(admin2).signValidatorProposal(0);

      expect(await contract.isValidator(candidate1.address)).to.be.true;
    });
  });

  describe("Admin Removal", function () {
    beforeEach(async function () {
      await contract.connect(admin1).proposeAddAdmin(admin2.address);
      await contract.connect(admin1).proposeAddAdmin(admin3.address);
      await contract.connect(admin2).signAdminProposal(1);
    });

    it("should remove admin with majority approval", async function () {
      await contract.connect(admin1).proposeRemoveAdmin(admin3.address);

      await expect(
        contract.connect(admin2).signAdminProposal(2)
      ).to.emit(contract, "AdminRemoved");

      expect(await contract.isAdmin(admin3.address)).to.be.false;
      expect(await contract.getAdminCount()).to.equal(2);
      expect(await contract.getThreshold()).to.equal(2);
    });

    it("should reject removing last admin", async function () {
      await contract.connect(admin1).proposeRemoveAdmin(admin2.address);
      await contract.connect(admin2).signAdminProposal(2);

      await contract.connect(admin1).proposeRemoveAdmin(admin3.address);
      await contract.connect(admin3).signAdminProposal(3);

      await expect(
        contract.connect(admin1).proposeRemoveAdmin(admin1.address)
      ).to.be.revertedWith("Cannot remove last admin");
    });

    it("should reject removed admin from acting", async function () {
      await contract.connect(admin1).proposeRemoveAdmin(admin3.address);
      await contract.connect(admin2).signAdminProposal(2);

      await expect(
        contract.connect(admin3).proposeAddAdmin(admin4.address)
      ).to.be.revertedWith("Only admin");
    });
  });

  describe("Access Control", function () {
    it("should reject non-admin proposal creation", async function () {
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");

      await expect(
        contract.connect(candidate2).proposeApproval(candidate1.address, "Approved")
      ).to.be.revertedWith("Only admin");
    });

    it("should reject non-admin signing", async function () {
      await contract.connect(admin1).proposeAddAdmin(admin2.address);
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");

      await expect(
        contract.connect(candidate2).signValidatorProposal(0)
      ).to.be.revertedWith("Only admin");
    });
  });

  describe("Query Functions", function () {
    it("should return correct admin list", async function () {
      await contract.connect(admin1).proposeAddAdmin(admin2.address);

      const admins = await contract.getAdmins();
      expect(admins.length).to.equal(2);
      expect(admins).to.include(admin1.address);
      expect(admins).to.include(admin2.address);
    });

    it("should return correct validator list", async function () {
      const validators = await contract.getValidators();
      expect(validators.length).to.equal(4);
    });

    it("should return proposal signatures", async function () {
      await contract.connect(admin1).proposeAddAdmin(admin2.address);
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");
      await contract.connect(admin1).proposeApproval(candidate1.address, "Approved");

      const sigs = await contract.getValidatorProposalSignatures(0);
      expect(sigs.length).to.equal(1);
      expect(sigs[0]).to.equal(admin1.address);
    });
  });

  describe("Event Emissions", function () {
    it("should emit ApplicationSubmitted event", async function () {
      await expect(
        contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com")
      ).to.emit(contract, "ApplicationSubmitted")
        .withArgs(candidate1.address, "ACME Corp");
    });

    it("should emit ValidatorApproved event", async function () {
      await contract.connect(candidate1).applyToBeValidator("ACME Corp", "test@acme.com");

      await expect(
        contract.connect(admin1).proposeApproval(candidate1.address, "Approved")
      ).to.emit(contract, "ValidatorApproved")
        .withArgs(candidate1.address);
    });

    it("should emit AdminAdded event with correct threshold", async function () {
      await expect(
        contract.connect(admin1).proposeAddAdmin(admin2.address)
      ).to.emit(contract, "AdminAdded")
        .withArgs(admin2.address, 2);
    });
  });
});
