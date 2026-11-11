// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract CertRegistry {

    // Alamat dua pihak yang memiliki peran khusus
    address public immutable issuerA;
    address public immutable approverB;

    // Struktur data satu sertifikat
    struct Certificate {
        bytes32 pdfHash;
        address issuer;
        bool exists;
        bool revoked;
    }

    // Penyimpanan sertifikat berdasarkan ID
    mapping(string => Certificate) private certificates;

    enum RevokeStatus { None, Pending, Approved, Rejected }

    struct RevokeProposal {
        bytes32 baHash;
        RevokeStatus status;
    }

    uint256 private proposalCount;
    mapping(string => uint256) public pendingProposalId;
    mapping(string => mapping(uint256 => RevokeProposal)) public revokeProposals;

    event RevokeProposed(
        string certificateId,
        uint256 indexed pid,
        bytes32 baHash,
        address indexed proposer
    );

    event RevokeReviewed(
        string certificateId,
        uint256 indexed pid,
        bool approved,
        address indexed reviewer
    );

    event Revoked(string certificateId, uint256 indexed pid);
        
    // Catatan peristiwa ketika sertifikat diterbitkan
    event Issued(
        string certificateId,
        bytes32 pdfHash,
        address indexed issuer
    );

    // Dijalankan sekali saat kontrak dibuat
    constructor(address _issuerA, address _approverB) {
        require(_issuerA != address(0), "Invalid issuer");
        require(_approverB != address(0), "Invalid approver");
        require(_issuerA != _approverB, "A and B must differ");

        issuerA = _issuerA;
        approverB = _approverB;
    }

    // Fungsi untuk menerbitkan sertifikat
    function issue(
        string calldata id,
        bytes32 pdfHash
    ) external {

        require(msg.sender == issuerA, "Only issuer A");
        require(bytes(id).length > 0, "ID is empty");
        require(pdfHash != bytes32(0), "Hash is empty");
        require(!certificates[id].exists, "ID already used");

        certificates[id] = Certificate({
            pdfHash: pdfHash,
            issuer: msg.sender,
            exists: true,
            revoked: false
        });

        emit Issued(id, pdfHash, msg.sender);
    }
    function proposeRevoke(string calldata id, bytes32 baHash) external {
        require(msg.sender == issuerA, "Only issuer A");

        Certificate storage cert = certificates[id];
        require(cert.exists, "Certificate not found");
        require(!cert.revoked, "Certificate already revoked");
        require(baHash != bytes32(0), "BA hash is empty");
        require(pendingProposalId[id] == 0, "Proposal already pending");

        uint256 pid = ++proposalCount;
        revokeProposals[id][pid] = RevokeProposal(baHash, RevokeStatus.Pending);
        pendingProposalId[id] = pid;

        emit RevokeProposed(id, pid, baHash, msg.sender);
    }
    function reviewRevoke(string calldata id, uint256 pid, bool ok) external {
        require(msg.sender == approverB, "Only approver B");

        Certificate storage cert = certificates[id];
        require(cert.exists, "Certificate not found");
        require(!cert.revoked, "Certificate already revoked");
        require(pid != 0 && pendingProposalId[id] == pid, "Proposal is not pending");

        RevokeProposal storage proposal = revokeProposals[id][pid];
        proposal.status = ok ? RevokeStatus.Approved : RevokeStatus.Rejected;
        delete pendingProposalId[id];

        emit RevokeReviewed(id, pid, ok, msg.sender);
        if (ok) {
            cert.revoked = true;
            emit Revoked(id, pid);
        }
    }  
    
    // Fungsi untuk memeriksa sertifikat
    function check(
        string calldata id,
        bytes32 candidateHash
    ) external view returns (
        bool exists,
        bool hashMatches,
        bool isRevoked,
        address recordedIssuer
    ) {

        Certificate storage cert = certificates[id];

        return (
            cert.exists,
            cert.exists && cert.pdfHash == candidateHash,
            cert.revoked,
            cert.issuer
        );
    }
}