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