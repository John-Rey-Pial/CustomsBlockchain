// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract SAD {
    event SADConstructed(address indexed contractAddress, address indexed importer);
    event FieldUpdated(string field, address indexed by);
    event FieldVerified(string field, address indexed by, Status status);
    event SADStatusChanged(Status newStatus, address indexed by);

    enum Status { Pending, Rejected, Validated }

    // Mandatory fields
    string private HSCode;
    uint256 private Quantity;      // 1e3 precision  e.g., 12560 = 12.56
    uint256 private UnitValue;     // 1e3 precision
    uint256 private TotalValue;    // 1e3 precision
    string private CountryOfOrigin;
    string private BankCode;
    uint256 private TotalCustomsTax;     // 1e3 precision
    bool private PaymentConfirmed;

    address public ImporterID;
    address public ExporterID;
    address public COC_ID;
    address public BOC_ID;
    address public PCHC_ID;

    // Optional fields
    string private ImportLicenseNumber;
    string private TaxExemptionCertNumber;
    uint256 private TaxExemptionAmount;     // 1e3 precision
    string private TaxCreditCertNumber;
    uint256 private TaxCreditAmount;     // 1e3 precision

    address public DOF_ID;
    address public LicenseAgency_ID;

    // Function Locks
    bool private Mandatory_Set;
    bool private  License_Set;
    bool private  TaxExemption_Set;
    bool private TaxCredit_Set;

    //SAD Status
    Status public SAD_Status;

    // Verification Map
    mapping(string => Status) private verifications;

    // Modifiers
    modifier onlyImporter() {
        require(msg.sender == ImporterID, "Only importers and customs brokers are authorized to perform this action");
        require(SAD_Status == Status.Pending, "SAD finalized");
        _;
    }

    modifier sadFinal() {
        require(SAD_Status == Status.Pending, "SAD finalized");
        _;
    }

    // Construct SAD
    constructor(
        address _ExporterID, 
        address _COC_ID, 
        address _BOC_ID,
        address _PCHC_ID
    ){
        ImporterID = msg.sender;
        ExporterID = _ExporterID;
        COC_ID = _COC_ID;
        BOC_ID = _BOC_ID;
        PCHC_ID = _PCHC_ID;
        SAD_Status = Status.Pending;

        emit SADConstructed(address(this), ImporterID);
    }

    // Functions for Setting Data Fields
    // Mandatory fields
    function setMandatoryFields(
        string memory _HSCode, 
        uint256 _quantity, 
        uint256 _unitValue,
        string memory _CountryOfOrigin,
        string memory _BankCode,
        uint256 _TotalCustomsTax
    ) external onlyImporter{
        require(!Mandatory_Set, "Can not change Mandatory Fields");
        HSCode = _HSCode;
        Quantity = _quantity;
        UnitValue = _unitValue;
        TotalValue = Quantity * UnitValue;
        CountryOfOrigin = _CountryOfOrigin;
        BankCode = _BankCode;
        TotalCustomsTax = _TotalCustomsTax;

        verifications["Cargo"] = Status.Pending;
        verifications["CountryOfOrigin"] = Status.Pending;
        verifications["BankCode"] = Status.Pending;
        verifications["TotalCustomsTax"] = Status.Pending;

        Mandatory_Set = true;
        emit FieldUpdated("Mandatory Fields", ImporterID);
    }

    // Optional: Import License Details
    function setLicenseDetails(
        address _LicenseAgency_ID, 
        string memory _importLicenseNumber
    ) external onlyImporter{
        require(!License_Set, "Can not change license details");
        LicenseAgency_ID = _LicenseAgency_ID;
        ImportLicenseNumber = _importLicenseNumber;
        verifications["License"] = Status.Pending;
        License_Set = true;
        emit FieldUpdated("Import License Details", ImporterID);
    }
    
    // Optional: DOF addresses
    function setDOFAgency(address _DOF_ID) external onlyImporter{
        require(DOF_ID == address(0), "Can not change DOF address");
        DOF_ID = _DOF_ID;
        emit FieldUpdated("DOF Address", ImporterID);
    }

    // Optional: Tax Exemption details
    function setTaxExemptionDetails(string memory _taxExCert,  uint256 _taxExAmt) external onlyImporter{
        require(!TaxExemption_Set, "Can not change tax exemption details");
        TaxExemptionCertNumber = _taxExCert;
        TaxExemptionAmount = _taxExAmt;
        verifications["Exemption"] = Status.Pending;
        TaxExemption_Set = true;
        emit FieldUpdated("Tax Exemption Details", ImporterID);
    }

    // Optional: set Tax Credit details
    function setTaxECreditDetails(string memory _taxCreditCert,  uint256 _taxCreditAmt) external onlyImporter{
        require(!TaxCredit_Set, "Can not change tax credit details");
        TaxCreditCertNumber = _taxCreditCert;
        TaxCreditAmount = _taxCreditAmt;
        verifications["Credit"] = Status.Pending;
        TaxCredit_Set = true;
        emit FieldUpdated("Tax Credit Details", ImporterID);
    }

    // Mandatory: verify Exporter Details
    function verifyCargoDetails(Status Cargo_Status) external sadFinal{
        require(msg.sender == ExporterID, "Only exporter can verify cargo details");
        verifications["Cargo"] = Cargo_Status;

        if (Cargo_Status == Status.Rejected) {
            SAD_Status = Status.Rejected;
            emit SADStatusChanged(Cargo_Status, ExporterID); 
        }

        emit FieldVerified("Cargo Details", ExporterID, Cargo_Status); 
    }

    // Functions for Verifying Data Fields
    // Mandatory: verify Country Of Origin
    function verifyCountryOfOrigin(Status COO_Status) external sadFinal{
        require(msg.sender == COC_ID, "Only the chamber of commerce can verify the country of origin");
        verifications["CountryOfOrigin"]= COO_Status;

        if (COO_Status == Status.Rejected) {
            SAD_Status = Status.Rejected;
            emit SADStatusChanged(COO_Status, COC_ID); 
        }

        emit FieldVerified("Country of Origin", COC_ID, COO_Status);
    }

    // Mandatory: verify Bank Code
    function verifyBankCode(Status BKCode_Status) external sadFinal{
        require(msg.sender == BOC_ID, "Only the bureau of customs can verify the bank code");
        verifications["BankCode"]= BKCode_Status;
    
        if (BKCode_Status == Status.Rejected){
            SAD_Status = Status.Rejected;
            emit SADStatusChanged(BKCode_Status, BOC_ID); 
        }

        emit FieldVerified("Bank Code", BOC_ID, BKCode_Status);
    }

    // Optional: verify Import License
    function verifyImportLicense(Status License_Status) external sadFinal{
        require(msg.sender == LicenseAgency_ID, "Only the license agency can verify import licenses");
        verifications["License"] = License_Status;

        if (License_Status == Status.Rejected){
            SAD_Status = Status.Rejected;
            emit SADStatusChanged(License_Status, LicenseAgency_ID); 
        }

        emit FieldVerified("Import License", LicenseAgency_ID, License_Status);
    }

    // Optional: verify Tax Exemptions and Credits
    function verifyTaxExemptionsAndCredits(Status ExemptionAndCredit_Status) external sadFinal{
        require(msg.sender == DOF_ID, "Only the DOF can verify tax exemptions and credits");
        verifications["Exemption"] = ExemptionAndCredit_Status;
        verifications["Credit"] = ExemptionAndCredit_Status;

        if (ExemptionAndCredit_Status == Status.Rejected){
            SAD_Status = Status.Rejected;
            emit SADStatusChanged(ExemptionAndCredit_Status, DOF_ID); 
        }

        emit FieldVerified("Tax Exemptions and Credits", DOF_ID, ExemptionAndCredit_Status);
    }

    // Mandatory: verify Total Customs Tax
    function verifyTotalCustomsTax(Status Tax_Status) external sadFinal{
        require(msg.sender == BOC_ID, "Only the bureau of customs can verify total customs taxes");
        require(verifications["Cargo"] == Status.Validated, "Cargo details have not been validated");
        require(verifications["CountryOfOrigin"]== Status.Validated, "Country of Origin have not been validated");
        require(verifications["BankCode"]== Status.Validated, "Bank Code has not been validated");

        if (License_Set){
            require(verifications["License"] == Status.Validated, "Import License has not been validated");
        }

        if (TaxExemption_Set){
            require(verifications["Exemption"] == Status.Validated, "Tax Exemption has not been validated");
        }

        if (TaxCredit_Set){
            require(verifications["Credit"] == Status.Validated, "Tax Credit has not been validated");
        }

        verifications["TotalCustomsTax"] = Tax_Status;

        if (Tax_Status == Status.Rejected){
            SAD_Status = Status.Rejected;
            emit SADStatusChanged(Tax_Status, BOC_ID); 
        }

        emit FieldVerified("Total Customs Tax", BOC_ID, Tax_Status);
    }
     
    function confirmPayment() external sadFinal{
        require(msg.sender == PCHC_ID, "Only PCHC can confirm payment");
        require(verifications["TotalCustomsTax"] == Status.Validated, "Total Customs Tax has not been validated");

        PaymentConfirmed = true;
        SAD_Status = Status.Validated;

        emit SADStatusChanged(Status.Validated, PCHC_ID); 
    }

    // Functions for Verifying Data Fields
    // Importer, Customs Broker, and BOC getter function
    function viewAllFields() external view returns (
        string memory hsCode,
        uint256 quantity,
        uint256 unitValue,
        uint256 totalValue,
        string memory countryOfOrigin,
        string memory bankCode,
        uint256 totalCustomsTax,
        string memory importLicenseNumber,
        string memory taxExemptionCertNumber,
        uint256 taxExemptionAmount,
        string memory taxCreditCertNumber,
        uint256 taxCreditAmount
    ) {
    require(msg.sender == ImporterID || msg.sender == BOC_ID, "Not authorized to view");
    return (
        HSCode,
        Quantity,
        UnitValue,
        TotalValue,
        CountryOfOrigin,
        BankCode,
        TotalCustomsTax,
        ImportLicenseNumber,
        TaxExemptionCertNumber,
        TaxExemptionAmount,
        TaxCreditCertNumber,
        TaxCreditAmount
        );
    }

    // Exporter getter function
    function viewExporter() external view returns (
        string memory hsCode,
        uint256 quantity,
        uint256 unitValue,
        uint256 totalValue
    ) {
        require(msg.sender == ExporterID, "Not authorized to view");
        return (HSCode, Quantity, UnitValue, TotalValue);
    }

    // Chamber of Commerce getter function
    function viewCOC() external view returns (string memory) {
        require(msg.sender == COC_ID, "Not authorized to view");
        return CountryOfOrigin;
    }

    // License Agency getter function
    function viewLicenseAgency() external view returns (string memory) {
        require(msg.sender == LicenseAgency_ID, "Not authorized to view");
        return ImportLicenseNumber;
    }

    // Department of Finance getter function
    function viewDOF() external view returns (
        string memory taxExemptionCert,
        uint256 taxExemptionAmount,
        string memory taxCreditCert,
        uint256 taxCreditAmount
    ) {
        require(msg.sender == DOF_ID, "Not authorized to view");
        return (
            TaxExemptionCertNumber,
            TaxExemptionAmount,
            TaxCreditCertNumber,
            TaxCreditAmount
        );
    }
    
    // Philippine Clearing House Corporation getter function
    function viewPCHC() external view returns (
        uint256 totalCustomsTax,
        string memory bankCode
    ) {
        require(msg.sender == PCHC_ID, "Not authorized to view");
        return (TotalCustomsTax, BankCode);
    }
}