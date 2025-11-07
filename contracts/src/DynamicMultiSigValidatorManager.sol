// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract DynamicMultiSigValidatorManager {

    address[] public admins;
    mapping(address => bool) public isAdmin;

    address[] private validators;
    mapping(address => bool) public isValidator;

    struct Application {
        address candidate;
        string organization;
        string contactEmail;
        uint256 submittedAt;
        bool isPending;
    }

    mapping(address => Application) public applications;

    struct AdminProposal {
        address candidate;
        bool isAddition;
        address[] signatures;
        mapping(address => bool) hasSigned;
        bool executed;
        uint256 createdAt;
    }

    struct ValidatorProposal {
        address candidate;
        bool isApproval;
        address[] signatures;
        mapping(address => bool) hasSigned;
        bool executed;
        string reason;
        uint256 createdAt;
    }

    uint256 public adminProposalCount;
    mapping(uint256 => AdminProposal) public adminProposals;

    uint256 public validatorProposalCount;
    mapping(uint256 => ValidatorProposal) public validatorProposals;

    event AdminAdded(address indexed admin, uint256 newThreshold);
    event AdminRemoved(address indexed admin, uint256 newThreshold);
    event ApplicationSubmitted(address indexed candidate, string organization);
    event ValidatorProposalCreated(uint256 indexed proposalId, address indexed candidate, bool isApproval);
    event ValidatorProposalSigned(uint256 indexed proposalId, address indexed admin);
    event ValidatorProposalExecuted(uint256 indexed proposalId, address indexed candidate);
    event ValidatorApproved(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event AdminProposalCreated(uint256 indexed proposalId, address indexed candidate, bool isAddition);
    event AdminProposalSigned(uint256 indexed proposalId, address indexed admin);
    event AdminProposalExecuted(uint256 indexed proposalId, address indexed candidate);

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Only admin");
        _;
    }

    constructor(
        address initialAdmin,
        address[] memory _initialValidators
    ) {
        require(initialAdmin != address(0), "Invalid admin");

        admins.push(initialAdmin);
        isAdmin[initialAdmin] = true;
        emit AdminAdded(initialAdmin, getThreshold());

        for (uint i = 0; i < _initialValidators.length; i++) {
            address validator = _initialValidators[i];
            require(validator != address(0), "Invalid validator");
            require(!isValidator[validator], "Duplicate validator");

            validators.push(validator);
            isValidator[validator] = true;
        }
    }

    function getThreshold() public view returns (uint256) {
        uint256 adminCount = admins.length;
        if (adminCount == 0) return 0;
        return (adminCount / 2) + 1;
    }

    function applyToBeValidator(
        string calldata organization,
        string calldata contactEmail
    ) external {
        require(!isValidator[msg.sender], "Already validator");
        require(!applications[msg.sender].isPending, "Application pending");

        applications[msg.sender] = Application({
            candidate: msg.sender,
            organization: organization,
            contactEmail: contactEmail,
            submittedAt: block.timestamp,
            isPending: true
        });

        emit ApplicationSubmitted(msg.sender, organization);
    }

    function proposeAddAdmin(address newAdmin)
        external
        onlyAdmin
        returns (uint256 proposalId)
    {
        require(newAdmin != address(0), "Invalid address");
        require(!isAdmin[newAdmin], "Already admin");

        proposalId = adminProposalCount++;
        AdminProposal storage proposal = adminProposals[proposalId];

        proposal.candidate = newAdmin;
        proposal.isAddition = true;
        proposal.createdAt = block.timestamp;
        proposal.executed = false;

        emit AdminProposalCreated(proposalId, newAdmin, true);
        _signAdminProposal(proposalId);

        return proposalId;
    }

    function proposeRemoveAdmin(address admin)
        external
        onlyAdmin
        returns (uint256 proposalId)
    {
        require(isAdmin[admin], "Not an admin");
        require(admins.length > 1, "Cannot remove last admin");

        proposalId = adminProposalCount++;
        AdminProposal storage proposal = adminProposals[proposalId];

        proposal.candidate = admin;
        proposal.isAddition = false;
        proposal.createdAt = block.timestamp;
        proposal.executed = false;

        emit AdminProposalCreated(proposalId, admin, false);
        _signAdminProposal(proposalId);

        return proposalId;
    }

    function signAdminProposal(uint256 proposalId) external onlyAdmin {
        _signAdminProposal(proposalId);
    }

    function _signAdminProposal(uint256 proposalId) internal {
        AdminProposal storage proposal = adminProposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(!proposal.hasSigned[msg.sender], "Already signed");

        proposal.signatures.push(msg.sender);
        proposal.hasSigned[msg.sender] = true;

        emit AdminProposalSigned(proposalId, msg.sender);

        uint256 threshold = getThreshold();
        if (proposal.signatures.length >= threshold) {
            _executeAdminProposal(proposalId);
        }
    }

    function _executeAdminProposal(uint256 proposalId) internal {
        AdminProposal storage proposal = adminProposals[proposalId];
        require(!proposal.executed, "Already executed");

        uint256 threshold = getThreshold();
        require(proposal.signatures.length >= threshold, "Insufficient signatures");

        proposal.executed = true;

        if (proposal.isAddition) {
            admins.push(proposal.candidate);
            isAdmin[proposal.candidate] = true;
            emit AdminAdded(proposal.candidate, getThreshold());
        } else {
            for (uint i = 0; i < admins.length; i++) {
                if (admins[i] == proposal.candidate) {
                    admins[i] = admins[admins.length - 1];
                    admins.pop();
                    break;
                }
            }
            isAdmin[proposal.candidate] = false;
            emit AdminRemoved(proposal.candidate, getThreshold());
        }

        emit AdminProposalExecuted(proposalId, proposal.candidate);
    }

    function proposeApproval(
        address candidate,
        string calldata reason
    ) external onlyAdmin returns (uint256 proposalId) {
        require(applications[candidate].isPending, "No pending application");
        require(!isValidator[candidate], "Already validator");

        proposalId = validatorProposalCount++;
        ValidatorProposal storage proposal = validatorProposals[proposalId];

        proposal.candidate = candidate;
        proposal.isApproval = true;
        proposal.reason = reason;
        proposal.createdAt = block.timestamp;
        proposal.executed = false;

        emit ValidatorProposalCreated(proposalId, candidate, true);
        _signValidatorProposal(proposalId);

        return proposalId;
    }

    function proposeRemoval(
        address validator,
        string calldata reason
    ) external onlyAdmin returns (uint256 proposalId) {
        require(isValidator[validator], "Not a validator");

        proposalId = validatorProposalCount++;
        ValidatorProposal storage proposal = validatorProposals[proposalId];

        proposal.candidate = validator;
        proposal.isApproval = false;
        proposal.reason = reason;
        proposal.createdAt = block.timestamp;
        proposal.executed = false;

        emit ValidatorProposalCreated(proposalId, validator, false);
        _signValidatorProposal(proposalId);

        return proposalId;
    }

    function signValidatorProposal(uint256 proposalId) external onlyAdmin {
        _signValidatorProposal(proposalId);
    }

    function _signValidatorProposal(uint256 proposalId) internal {
        ValidatorProposal storage proposal = validatorProposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(!proposal.hasSigned[msg.sender], "Already signed");

        proposal.signatures.push(msg.sender);
        proposal.hasSigned[msg.sender] = true;

        emit ValidatorProposalSigned(proposalId, msg.sender);

        uint256 threshold = getThreshold();
        if (proposal.signatures.length >= threshold) {
            _executeValidatorProposal(proposalId);
        }
    }

    function _executeValidatorProposal(uint256 proposalId) internal {
        ValidatorProposal storage proposal = validatorProposals[proposalId];
        require(!proposal.executed, "Already executed");

        uint256 threshold = getThreshold();
        require(proposal.signatures.length >= threshold, "Insufficient signatures");

        proposal.executed = true;

        if (proposal.isApproval) {
            validators.push(proposal.candidate);
            isValidator[proposal.candidate] = true;
            applications[proposal.candidate].isPending = false;
            emit ValidatorApproved(proposal.candidate);
        } else {
            require(validators.length > 1, "Cannot remove last validator");
            for (uint i = 0; i < validators.length; i++) {
                if (validators[i] == proposal.candidate) {
                    validators[i] = validators[validators.length - 1];
                    validators.pop();
                    break;
                }
            }
            isValidator[proposal.candidate] = false;
            emit ValidatorRemoved(proposal.candidate);
        }

        emit ValidatorProposalExecuted(proposalId, proposal.candidate);
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    function getValidatorCount() external view returns (uint256) {
        return validators.length;
    }

    function getAdminCount() external view returns (uint256) {
        return admins.length;
    }

    function getAdmins() external view returns (address[] memory) {
        return admins;
    }

    function getValidatorProposalSignatures(uint256 proposalId)
        external
        view
        returns (address[] memory)
    {
        return validatorProposals[proposalId].signatures;
    }

    function getAdminProposalSignatures(uint256 proposalId)
        external
        view
        returns (address[] memory)
    {
        return adminProposals[proposalId].signatures;
    }
}
