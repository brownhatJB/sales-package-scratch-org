/**
 * @module             : Real_Estate_Module
 * @description        : LWC component used to search for available units and select them and shortlist , create sales proposal and offers
 * @namespace          :
 * @author             : SREERAM.R
 * @group              : Search Page
 * @last modified on   : 07-30-2026
 * @last modified by   : SREERAM.R
 **/
import { LightningElement, wire, track } from "lwc";

//Salesforce functionsembed
import { updateRecord } from "lightning/uiRecordApi";
import { CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import refreshApex from "@salesforce/apex";

//Apex classes
import getunits from "@salesforce/apex/UnitsearchDynamicSoql.getunits";
//import getunitsPreferenceSearch from "@salesforce/apex/UnitPreferenceSearchDynamicSoql.getunits";
import getSelectedUnits from "@salesforce/apex/GetSelectedUnitsUnitSearch.getSelectedUnits";
import createProposalWithSelectedUnits from "@salesforce/apex/CreateSalesProposal.createProposalWithSelectedUnits";
import createOfferWithSelectedUnits from "@salesforce/apex/CreateOffer.createOfferWithSelectedUnits";
import createPAU from "@salesforce/apex/batchApexPAU.createPAU";
import getUnitsPau from "@salesforce/apex/PauUnitSearchDataRetrieve.getUnits";
import getParkingUnits from "@salesforce/apex/GetParkingUnitsUnitSearch.parkingUnitsWire";
import getFieldSet from "@salesforce/apex/UnitSearchFieldListPreferenceSearch.getFieldSet";
// import getFieldSetParking from "@salesforce/apex/UnitSearchParkingFieldListSearch.getFieldSet";
// import getFieldSetPaymentPlanSet from "@salesforce/apex/UnitSearchSetPaymentPlanFieldListSearch.getFieldSet";
//import savePreference from "@salesforce/apex/ShortlistUnitsController.savePreference";
import checkReservationConflict from "@salesforce/apex/CreateOffer.checkReservationConflict";
import sendConflictAlert from "@salesforce/apex/CreateOffer.sendConflictAlert";
import validateUnitAvailability from "@salesforce/apex/CreateOffer.validateUnitAvailability";
import getParkingUnitsConfiguration from "@salesforce/apex/UnitSearchConfigurationController.getParkingUnitsConfiguration";
import getUnitSearchTableConfiguration from "@salesforce/apex/UnitSearchConfigurationController.getUnitSearchTableConfiguration";

//Salesforce object schema api names
// import ID_FIELD from "@salesforce/schema/Units__c.Id";
// import ENQUIRY_FIELD from "@salesforce/schema/Units__c.Enquiry__c";
import PROPERTY_ATTRIBUTE_UPDATE_OBJECT from "@salesforce/schema/Property_Attribute_Update__c";
import ENQUIRY_OBJECT from "@salesforce/schema/Enquiry__c";
import UNIT_PREFERENCE__OBJECT from "@salesforce/schema/Unit_Preference__c";
import OPPORTUNITY_OBJECT from "@salesforce/schema/Opportunity";
import STAGE_NAME from "@salesforce/schema/Enquiry__c.Stage__c";
import ENQUIRY_ID_FIELD from "@salesforce/schema/Enquiry__c.Id";

//Table columns
const colums = [];
const columns = [];

const CONFLICT_COLUMNS = [
  {
    label: "Unit",
    fieldName: "UnitName"
  },
  {
    label: "Offer Name",
    fieldName: "Name"
  },
  {
    label: "Owner",
    fieldName: "OwnerName"
  },
  {
    label: "Status",
    fieldName: "pflexmet__Status__c"
  },
  {
    label: "Created Date",
    fieldName: "formattedCreatedDate"
  }
];

export default class unitsearchtable extends NavigationMixin(LightningElement) {
  connectedCallback() {
    this.FilterValues = {};
    this.showUnitSearchOverlay = true;
  }
  //Variables
  @track recordId;
  @track FilterValues = {};
  accounts = [];
  createOfferSalesProposalData = {};
  @track selectedRecordIds = [];
  @track selectedParkingRecordCheck = [];
  @track selectedParkingRecordIds = [];
  wiredRecords;
  @track fields = [];
  @track joinedFields = "";
  @track data;
  @track error;
  @track items = [];
  @track recordCount = 20;
  @track loadMoreStatus = "";
  @track totalRecountCount = 0;
  @track targetDatatable;
  @track allUnits = [];
  @track showUnitSearchOverlay = false;
  selectdunitsforpaymentplanset = [];
  prefId;
  cols = colums;
  col;
  column = columns;
  visibleProducts = [];
  selectedRecordMap = {};
  selectedParkingRecordMap = {};
  unitParkingRecordMap = {};
  selectedUnits;
  objectApiName;
  varPAUId;
  activityType;
  enquiryId;
  opportunityId;
  isPropertyAttributeUpdate = false;
  isEnquiry = false;
  records;
  @track isModalOpen = false;
  @track parkingModalClass = "slds-hide";
  selectedUnitId;
  wiredParkingUnits;
  wiredParkingUnitsRecords;
  parkingUnitsSelected = [];
  @track displayedFields;
  @track displayedFieldsParking;
  queryFields;
  queryFieldsParking;
  @track unitPreferenceId;
  @track bedrooms;
  @track minAmt;
  @track maxAmt;
  @track minArea;
  @track unitType;
  @track propertyId;
  @track prefRecordId;
  @track view;
  @track floor;
  @track maxArea;
  @track parkingUnitsAvailable = false;
  @track isTableVisible = false;
  @track NotPreferenceSearch = true;

  //btn ui promise state : )
  isPurchaseLoading = false;
  isShortlistLoading = false;
  isCreateProposalLoading = false;

  //parking Setting
  parkingSetting = [];

  //reservation conflict variables
  showConflictModal = false;
  conflictingOffers = [];
  conflictColumns = CONFLICT_COLUMNS;
  isProceedLoading = false;

  // Reservation processing overlay
  showReservationOverlay = false;
  progressValue = 0;
  progressStatus = "";
  currentStep = 0;
  progressTimer;

  // Offer configuration state management
  showPromotionPrompt = false;
  showOfferConfiguration = false;
  unitSearchTableConfiguration = [];

  //LifeCycle Hooks
  connectedCallback() {
    this.loadParkingUnitsConfiguration();
  }


  //Wires
  //get page reference values passed from detail page button from which this lwc page is opened
  @wire(CurrentPageReference)
  currentPageReferenceHandler(pageRef) {
    console.log("currentPageReferenceHandler : " + pageRef);
    console.log("isEnquiry : " + this.isEnquiry);
    console.log("ENQUIRY_OBJECT.objectApiName: ", ENQUIRY_OBJECT.objectApiName);
    if (pageRef) {
      const { state } = pageRef;
      const {
        c__varPAUId,
        c__activityType,
        c__objectApiName,
        c__enqRecordId,
        c__opportunityRecordId,
        c__bedrooms,
        c__minAmt,
        c__maxAmt,
        c__minArea,
        c__unitType,
        c__propertyId,
        c__prefRecordId,
        c__view,
        c__floor,
        c__maxarea,
        c__unitPreferenceId
      } = state;
      console.log("c__objectApiName : " + c__objectApiName);
      console.log("c__enqRecordId : " + c__enqRecordId);
      console.log("c__opportunityRecordId : " + c__opportunityRecordId);
      console.log(
        "ENQUIRY_OBJECT.objectApiName : " + ENQUIRY_OBJECT.objectApiName
      );
      console.log(
        "OPPORTUNITY_OBJECT.objectApiName : " + OPPORTUNITY_OBJECT.objectApiName
      );
      if (c__objectApiName === ENQUIRY_OBJECT.objectApiName) {
        this.isEnquiry = c__objectApiName === ENQUIRY_OBJECT.objectApiName;
        this.enquiryId = c__enqRecordId;
        this.objectApiName = "Enquiry__c";
        this.recordId = c__enqRecordId;
        console.log("isEnquiry : " + this.isEnquiry);
      } else if (
        c__objectApiName === PROPERTY_ATTRIBUTE_UPDATE_OBJECT.objectApiName
      ) {
        this.isPropertyAttributeUpdate =
          c__objectApiName === PROPERTY_ATTRIBUTE_UPDATE_OBJECT.objectApiName;
        this.varPAUId = c__varPAUId;
        this.activityType = c__activityType;
        this.objectApiName = "Property_Attribute_Update__c";
        this.recordId = c__varPAUId;
      } else if (c__objectApiName === UNIT_PREFERENCE__OBJECT.objectApiName) {
        this.NotPreferenceSearch = false;
        this.unitPreferenceId = c__unitPreferenceId;
        this.isEnquiry = ENQUIRY_OBJECT.objectApiName;
        this.enquiryId = c__enqRecordId;
        this.objectApiName = "Unit_Preference__c";
        this.recordId = c__prefRecordId;
        this.bedrooms = c__bedrooms;
        this.minAmt = c__minAmt;
        this.maxAmt = c__maxAmt;
        this.minArea = c__minArea;
        this.unitType = c__unitType;
        this.propertyId = c__propertyId;
        this.prefRecordId = c__prefRecordId;
        this.view = c__view;
        this.floor = c__floor;
        this.maxArea = c__maxarea;
      } else if (c__objectApiName === OPPORTUNITY_OBJECT.objectApiName) {
        this.isEnquiry = c__objectApiName;
        this.opportunityId = c__opportunityRecordId;
        this.objectApiName = "Opportunity";
        this.recordId = c__opportunityRecordId;
      }
    }
  }

  //get fields in json format to display
  @wire(getFieldSet, {
    sObjectName: "pflexmet__Units__c",
    fieldSetName: "pflexmet__Unit_Search",
    recordId: "$recordId"
  })
  async wiredFields({ error, data }) {
    if (data) {
      data = JSON.parse(data);
      console.log("unit search filter data : " + JSON.stringify(data, null, 2));
      let cols = [];
      let fields = [];
      data.forEach((currentItem) => {
        fields.push(currentItem.name);
        let col;
        if (currentItem.label === "Property Picture") {
          col = {
            label: "Property Picture",
            type: "customPictureType",
            typeAttributes: { pictureUrl: { fieldName: "propertyImage__c" } },
            cellAttributes: { alignment: "center" }
          };
        } else {
          if (currentItem.name === "Name") {
            col = {
              label: currentItem.label,
              fieldName: "recordLink",
              type: "url",
              typeAttributes: {
                label: {
                  fieldName: "Name"
                },
                target: "_self"
              }
            };
          } else {
            col = {
              label: currentItem.label,
              fieldName: currentItem.name
            };
          }
        }
        cols.push(col);
      });
      if (
        this.parkingSetting?.length &&
        this.parkingSetting[0]?.pflexmet__Show_Parking_Units__c &&
        (this.objectApiName === "Enquiry__c" ||
          this.objectApiName === "Unit_Preference__c" ||
          this.objectApiName === "Opportunity")
      ) {
        let buttonCol = {
          label: "Parking Units",
          type: "button",
          initialWidth: 80,
          typeAttributes: {
            label: "P",
            name: "view_details",
            title: "Click to Add Parking Units",
            disabled: false,
            value: "view_details",
            variant: "brand"
          }
        };
        cols.push(buttonCol);
      }
      this.col = cols;
      this.displayedFields = fields;
      this.queryCreation(this.displayedFields);
      if (
        this.objectApiName === "Enquiry__c" ||
        this.objectApiName === "Opportunity"
      ) {
        this.loadunits();
      } else if (this.objectApiName === "Unit_Preference__c") {
        this.loadunitsPreference();
      } else if (this.objectApiName === "Property_Attribute_Update__c") {
        this.createPauUnits();
      }
    } else if (error) {
      console.log(error);
      this.error = error;
      this.col = undefined;
    }
  }

  @wire(getUnitSearchTableConfiguration)
  wiredUnitSearchTableConfiguration({ data, error}) {
    if(data) {
      this.unitSearchTableConfiguration = data;
      console.log('unit search table configuration: ', JSON.stringify(this.unitSearchTableConfiguration, null, 2));
    }
    if(error) {
      console.error('Error while retrieving mdt - Unit_Search_Table_Setting__mdt', error);
    }
  }

  //get fields in json format to display for parking units
  // @wire(getFieldSetParking, { sObjectName: "pflexmet__Units__c", fieldSetName: "pflexmet__Parking_Unit_Search" })
  // wiredFieldsParking ({ error, data }) {
  //   if (data) {
  //     data = JSON.parse(data);
  //     let cols = [];
  //     let fields = [];
  //     data.forEach((currentItem) => {
  //       fields.push(currentItem.name);
  //       let col;
  //       if (currentItem.label === "Property Picture") {
  //         col = {
  //           label: "Property Picture",
  //           type: "customPictureType",
  //           typeAttributes: { pictureUrl: { fieldName: "propertyImage__c" } },
  //           cellAttributes: { alignment: "center" }
  //         };
  //       } else {
  //         col = { label: currentItem.label, fieldName: currentItem.name };
  //       }
  //       cols.push(col);
  //     });
  //     this.column = cols;
  //     this.displayedFieldsParking = fields;
  //     this.queryCreationParking(this.displayedFieldsParking);
  //   } else if (error) {
  //     console.log(error);
  //     this.error = error;
  //     this.column = undefined;
  //   }
  // }

  // @wire(getFieldSetPaymentPlanSet, { sObjectName: 'pflexmet__Units__c', fieldSetName: 'pflexmet__Unit_Search' })
  // wiredFieldsSetPaymentPlan ({ error, data }) {
  //   if (data) {
  //     this.fields = data;
  //     this.joinFields();
  //   } else if (error) {
  //     console.error('Error retrieving fields from field set:', error);
  //   }
  // }

  //wire parking unit settings (mdt)
  // @wire(getParkingUnitsConfiguration)
  // wiredParkingSetting({ data, error }) {
  //   if (data) {
  //     this.parkingSetting = data;
  //     console.log(
  //       "parking setting: ",
  //       JSON.stringify(this.parkingSetting, null, 2)
  //     );
  //   }
  //   if (error) {
  //     console.error(
  //       "error while retrieving custom mdt - parking units settings",
  //       error
  //     );
  //   }
  // }

  async loadParkingUnitsConfiguration() {
    try {
      this.parkingSetting = await getParkingUnitsConfiguration();
      console.log('parking setting: ', JSON.stringify(this.parkingSetting, null, 2));
    } catch(error) {
      console.log('Error while loading parking units configuration: ', error);
    }
  }

  //select units according to filter values
  @wire(getSelectedUnits, {
    unitIds: "$selectedRecordIds",
    fields: "$joinedFields"
  })
  getSelectedUnitsWire(value) {
    this.wiredRecords = value;
    const { data, error } = value;
    if (data) {
      this.records = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.records = undefined;
    }
  }

  //get parking units related to the property of the unit selected
  @wire(getParkingUnits, {
    recordId: "$selectedUnitId",
    fields: "$queryFieldsParking"
  })
  wiredParkingUnt(result) {
    const excludedKey = this.selectedUnitId;
    for (const key in this.unitParkingRecordMap) {
      if (key !== excludedKey) {
        const parkingUnits = this.unitParkingRecordMap[key];
        for (const id of parkingUnits) {
          if (!this.parkingUnitsSelected.includes(id)) {
            this.parkingUnitsSelected.push(id);
          }
        }
      }
    }
    this.wiredParkingUnits = result;
    if (result.data) {
      this.parkingUnitsAvailable = true;
      this.wiredParkingUnitsRecords = result.data.filter((record) => {
        return !this.parkingUnitsSelected.includes(record.Id);
      });
      this.isTableVisible = this.wiredParkingUnitsRecords.length > 0;
    } else {
      this.parkingUnitsAvailable = false;
      this.isTableVisible = false;
    }
    this.parkingUnitsSelected = [];
  }

  //Events
  //event helps in loading ore units for lazy loading
  handleLoadMore() {
    // Check if there are more items to load and avoid triggering if no more data is left
    if (this.recordCount < this.totalRecountCount) {
      this.recordCount += 20;
      this.loadMoreStatus = "Loading"; // Show loading spinner
      this.data = this.items.slice(0, this.recordCount);
    } else {
      //     // No more data to load
      //     this.loadMoreStatus = "";
      //     // Ensure you are only slicing up to the available count
      // this.data = this.items.slice(0, this.totalRecountCount);
    }

    console.log("this.recordCount : " + this.recordCount);
    console.log("this.totalRecountCount : " + this.totalRecountCount);
    console.log("this.loadMoreStatus : " + this.loadMoreStatus);
  }

  //event to open modal pop up to select parking units
  handleRowAction(event) {
    const actionName = event.detail.action.name;
    if (actionName === "view_details") {
      this.selectedUnitId = event.detail.row.Id;
      if (this.selectedUnitId) {
        if (this.unitParkingRecordMap[this.selectedUnitId]) {
          const selectedParkingRecordIds =
            this.unitParkingRecordMap[this.selectedUnitId];
          this.selectedParkingRecordCheck = selectedParkingRecordIds;
        }
      }
      this.showParkingModal();
    }
  }

  //method to handle selected units
  handleRowSelection(event) {
    const selectedRows = event.detail.selectedRows;
    JSON.stringify();
    switch (event.detail.config.action) {
      case "selectAllRows":
        this.selectedRecordMap = {};
        selectedRows.forEach((row) => {
          this.selectedRecordMap[row.Id] = true;
        });
        break;

      case "rowSelect":
        selectedRows.forEach((row) => {
          this.selectedRecordMap[row.Id] = true;
        });
        break;

      case "rowDeselect":
        for (const id in this.selectedRecordMap) {
          if (!selectedRows.find((selectedRow) => selectedRow.Id === id)) {
            delete this.selectedRecordMap[id];
          }
        }
        break;

      case "deselectAllRows":
        for (const id in this.selectedRecordMap) {
          if (!selectedRows.find((selectedRow) => selectedRow.Id === id)) {
            delete this.selectedRecordMap[id];
          }
        }
        break;

      default:
        break;
    }
    this.selectedRecordIds = Object.keys(this.selectedRecordMap);
  }

  //method to handle parking units selected
  handleRowSelectionParkingUnits(event) {
    const selectedRows = event.detail.selectedRows;
    JSON.stringify();
    switch (event.detail.config.action) {
      case "selectAllRows":
        this.selectedParkingRecordMap = {};
        selectedRows.forEach((row) => {
          this.selectedParkingRecordMap[row.Id] = true;
        });
        break;

      case "rowSelect":
        selectedRows.forEach((row) => {
          this.selectedParkingRecordMap[row.Id] = true;
        });
        break;

      case "rowDeselect":
        // alert('rowDeselect');
        for (const id in this.selectedParkingRecordMap) {
          if (!selectedRows.find((selectedRow) => selectedRow.Id === id)) {
            delete this.selectedParkingRecordMap[id];
          }
        }
        // alert(JSON.stringify(this.selectedRecordMap));
        break;

      case "deselectAllRows":
        // alert('deselectAllRows');
        for (const id in this.selectedParkingRecordMap) {
          if (!selectedRows.find((selectedRow) => selectedRow.Id === id)) {
            delete this.selectedParkingRecordMap[id];
          }
        }
        break;

      default:
        break;
    }
    this.selectedParkingRecordIds = Object.keys(this.selectedParkingRecordMap);
    if (event.detail.config.action) {
      this.unitParkingRecordMap[this.selectedUnitId] = Object.keys(
        this.selectedParkingRecordMap
      );
    }
  }

  //event from filter component to pass filter values to variables
  searchfilter(event) {
    console.log("Event Detail:", JSON.stringify(event.detail));
    this.FilterValues = event.detail;

    console.log("Filter Values:", JSON.stringify(this.FilterValues, null, 2));

    if (this.objectApiName === "Enquiry__c") {
      this.loadunits();
      console.log("After assignment:", JSON.stringify(this.FilterValues));
    } else if (this.objectApiName === "Unit_Preference__c") {
      this.loadunits();
    } else if (this.objectApiName === "Opportunity") {
      console.log("loadUnits for Opportunity");
      this.loadunits();
    } else if (this.objectApiName === "Property_Attribute_Update__c") {
      this.createPauUnits();
    }
  }

  //close set payment plan pop up
  closeModal() {
    this.isModalOpen = false;
  }

  //submit set payment plan pop up
  submitDetails() {
    this.isModalOpen = false;
  }

  //event used to shortlist units and redirect to enquiry
  async handleClick() {
    if (this.selectedRecordIds.length === 0) {
      this.showToast(
        "Warning",
        "Please select at least 1 unit to proceed",
        "warning"
      );
      return;
    }
    this.isShortlistLoading = true;

    // try {
    //   await savePreference({
    //     unitIds: this.selectedRecordIds,
    //     opportunityId: this.opportunityId ? this.opportunityId : null,
    //     enquiryId: this.enquiryId ? this.enquiryId : null,
    //     leadId: null
    //   });
    //   this.showToast(
    //     "Success",
    //     "Selected Units are shortlisted successfully",
    //     "success"
    //   );
    //   this.isShortlistLoading = true;
    //   this[NavigationMixin.Navigate]({
    //     type: "standard__recordPage",
    //     attributes: {
    //       recordId: this.enquiryId ? this.enquiryId : this.opportunityId,
    //       actionName: "view"
    //     }
    //   });
    // } catch (error) {
    //   this.showToast("Error", "Error shortlisting unit", "error");
    //   console.error("Error shortlisting unit:", error);
    //   this.isShortlistLoading = false;
    // }

    // const recordInputs = this.selectedRecordIds.map((itemId) => {
    //   const fields = {};
    //   fields[ID_FIELD.fieldApiName] = itemId;
    //   fields[ENQUIRY_FIELD.fieldApiName] = this.enquiryId;
    //   return { fields };
    // });
    // // alert(JSON.stringify(recordInputs));
    // const unitPromises = recordInputs.map((recordInput) =>
    //   updateRecord(recordInput, { ifUnmodifiedSince: this.lastModifiedDate })
    // );
    // Promise.all(unitPromises)
    //   .then(() => {
    //     this.showToast(
    //       "Success",
    //       "Selected Units are shortlisted successfully",
    //       "success"
    //     );
    //     this[NavigationMixin.Navigate]({
    //       type: "standard__recordPage",
    //       attributes: {
    //         recordId: this.enquiryId ? this.enquiryId : this.opportunityId,
    //         actionName: "view"
    //       }
    //     });
    //   })
    //   .catch(() => {
    //     this.showToast("Error", "Error shortlisting unit", "error");
    //     this.isShortlistLoading = false;
    //   });
    // this.updateEnquiryShortlisted();
  }

  //Event to create sales proposal with selected unit and redirect to sales proposal if only one is created and redirect to enquiry if multiple are created
  handleClickProposal() {
    if (this.selectedRecordIds.length <= 0) {
      this.showToast(
        "Warning",
        "Please select at least 1 unit to proceed",
        "warning"
      );
      return;
    }
    this.isCreateProposalLoading = true;
    const createOfferSalesProposalData = {
      enqRecordId: this.enquiryId ? this.enquiryId : null,
      Opportunity: this.opportunityId ? this.opportunityId : null,
      enquiry: "Sales Proposal",
      selectedIds: this.selectedRecordIds
    };
    createProposalWithSelectedUnits({
      createOfferSalesProposalData: createOfferSalesProposalData
    })
      .then((result) => {
        console.log("Sales Proposal Created:", result);
        const salesProposalId = result;
        this.showToast(
          "Success",
          "Sales Proposal created successfully",
          "success"
        );
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: salesProposalId,
            actionName: "view"
          }
        });
      })
      .catch((error) => {
        console.error("Error creating Sales Proposal:", error);
        this.showToast("Error", "Error creating Sales Proposal", "error");
        this.isCreateProposalLoading = false;
      });
  }

  //event to create offer for selected units and redirect to new offer if one one is created and to enquiry if multiple are created
  async handlePurchase() {
    if (this.selectedRecordIds.length <= 0) {
      this.showToast(
        "Warning",
        "Please select at least 1 unit to proceed",
        "warning"
      );
      return;
    }

    this.isPurchaseLoading = true;

    try {
      const unavailableUnits = await validateUnitAvailability({
        unitIds: this.selectedRecordIds
      });

      if (unavailableUnits.length > 0) {
        this.showToast(
          "Error",
          `The following units are no longer available: ${unavailableUnits.join(", ")}`,
          "error"
        );
        this.isPurchaseLoading = false;
        return;
      }
    } catch (error) {
      this.showToast(
        "Error",
        error?.body?.message || "Error validating unit availability.",
        "error"
      );
      this.isPurchaseLoading = false;
      return;
    }

    try {
      const conflicts = await checkReservationConflict({
        unitIds: this.selectedRecordIds
      });
      console.log(JSON.stringify(conflicts, null, 2));
      if (conflicts && conflicts.length > 0) {
        this.conflictingOffers = conflicts.map((item) => {
          return {
            ...item,
            UnitName: item.pflexmet__Unit__r?.Name,
            OwnerName: item.Owner?.Name,
            formattedCreatedDate: new Date(item.CreatedDate).toLocaleString()
          };
        });

        try {
          await sendConflictAlert({
            unitId: this.selectedRecordIds[0],
            oppId: this.opportunityId ? this.opportunityId : null,
            enquiryId: this.enquiryId ? this.enquiryId : null
          });
        } catch (error) {
          console.error("Failed to send Conflict Reservation Email: ", error);
        }
        this.isPurchaseLoading = false;
        this.showConflictModal = true;
        return;
      }
    } catch (error) {
      let errorMessage = "Error checking reservation conflicts";

      if (error?.body?.message) {
        errorMessage = error.body.message;
      }

      this.showToast("Error", errorMessage, "error");
      this.isPurchaseLoading = false;
      return;
    }

    this.handlePromotionFlow();
  }

  //set payment plan option pop up open
  handleSetPurchasePlanOption() {
    if (this.selectedRecordIds.length <= 0) {
      this.showToast(
        "Warning",
        "Please select at least 1 unit to proceed",
        "warning"
      );
      return;
    }
    this.isPurchaseLoading = false;
    this.isModalOpen = true;
  }

  //Navigating to newly created PAU record , Calling the batchApexPau apex class and sending parameters amd closing search tab
  handleInvokeBatchJob() {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.varPAUId,
        objectApiName: "Property_Attribute_Update__c",
        actionName: "view"
      }
    });
    this.callApexMethod(
      this.selectedRecordIds,
      this.varPAUId,
      this.activityType
    );
  }

  //this will check atleast one unit is selcted and proceed to next step also it will show a toast message.
  handleProceedParking() {
    if (Object.keys(this.selectedParkingRecordMap).length === 0) {
      this.showToast(
        "Warning",
        "Please select at least 1 parking unit to proceed",
        "warning"
      );
      return;
    }

    this.parkingModalClass = "slds-hide";
  }
  //closes parking modal pop up and clears values in variables
  closeParkingModal() {
    if (this.selectedUnitId) {
      if (this.unitParkingRecordMap[this.selectedUnitId]) {
        delete this.unitParkingRecordMap[this.selectedUnitId];
        this.selectedParkingRecordCheck = {};
      }
    }
    this.parkingModalClass = "slds-hide";
    this.wiredParkingUnitsRecords = {};
    this.selectedParkingRecordIds = {};
    this.selectedParkingRecordMap = {};
    this.selectedUnitId = "";
  }

  //Helper methods
  //used to call getLoadEnquiryMethod and call loadUnitsData method
  loadunits() {
    console.log("Inside loadunits:", JSON.stringify(this.FilterValues));

    this.showUnitSearchOverlay = true;

    this.recordCount = 20;
    this.data = [];
    this.items = [];

    console.log("Sending to Apex:", JSON.stringify(this.FilterValues));

    let loadMethod = this.getLoadEnquiryMethod();
    this.loadUnitsData(loadMethod);
  }

  //used to call getLoadMethod and call loadUnitsData method
  createPauUnits() {
    this.showUnitSearchOverlay = true;

    this.recordCount = 20;
    this.data = [];
    this.items = [];

    let loadMethod = this.getLoadMethod();
    this.loadUnitsData(loadMethod);
  }

  //used to set filter values to local variable
  getLoadEnquiryMethod() {
    let loadMethod;
    console.log(
      " JSON.stringify(this.FilterValues" + JSON.stringify(this.FilterValues)
    );
    console.log("this.queryFields " + this.queryFields);
    loadMethod = getunits({
      filterJson: JSON.stringify(this.FilterValues),
      fields: this.queryFields
    });
    return loadMethod;
  }

  loadunitsPreference() {
    this.showUnitSearchOverlay = true;

    this.recordCount = 20;
    this.data = [];
    this.items = [];

    let loadMethod = this.getLoadPreferenceMethod();
    this.loadUnitsData(loadMethod);
  }

  // getLoadPreferenceMethod() {
  //   let loadMethod;
  //   loadMethod = getunitsPreferenceSearch({
  //     recordID: this.recordId,
  //     fields: this.queryFields
  //   });
  //   return loadMethod;
  // }

  //getting units for pst passed on activity type
  getLoadMethod() {
    const activityType = this.activityType;
    let unitStatus;

    switch (activityType) {
      case "Update":
        unitStatus = "All";
        break;
      case "Block":
      case "Release":
        unitStatus = "Available";
        break;
      case "Unblock":
        unitStatus = "Blocked";
        break;
      default:
        console.warn(`Unknown activity type: ${activityType}`);
        unitStatus = "All"; // or some other default value
    }

    return getUnitsPau({
      filterValues: this.FilterValues,
      fields: this.queryFields,
      unitStatus: unitStatus
    });
  }

  queryCreation(value) {
    //console.log("Value JSON:", JSON.stringify(value));
    // fieldString = value.join(", ");
    this.queryFields = value.filter(field => field && field.trim()).join(", ");
    console.log("Query Fields : " + this.queryFields);
  }

  queryCreationParking(value) {
    let fieldString = value.join(", ");
    this.queryFieldsParking = fieldString;
  }

  joinFields() {
    if (this.fields && this.fields.length > 0) {
      this.joinedFields = this.fields.join(", ");
    } else {
      this.joinedFields = "";
    }
  }
  //format units and pass
  loadUnitsData(loadMethod) {
    if (loadMethod) {
      // Record when loading started
      const start = Date.now();

      loadMethod
        .then((result) => {
          if (result) {
            console.log("is this array: ", JSON.stringify(result));

            this.allUnits = result;
            this.processData(result);
          }
        })
        .catch((error) => {
          console.error("Error retrieving Units:", error);
        })
        .finally(async () => {
          // Calculate how long the request took
          const elapsed = Date.now() - start;

          // Keep loader visible for at least 500ms
          if (elapsed < 500) {
            await new Promise((resolve) =>
              // eslint-disable-next-line @lwc/lwc/no-async-operation
              setTimeout(resolve, 500 - elapsed)
            );
          }

          // Hide loader
          this.showUnitSearchOverlay = false;
        });
    }
  }

  //used to make the id column in table as a link
  processData(data) {
    const result = JSON.parse(JSON.stringify(data));
    result.forEach((record) => {
      record.recordLink = "/" + record.Id;
    });
    this.totalRecountCount = result.length;
    this.items = result;
    this.loadInitialData();
  }

  //use for lazy loadingd
  loadInitialData() {
    if (
      typeof this.totalRecountCount === "undefined" ||
      this.totalRecountCount === null
    ) {
      console.error("totalRecountCount is not defined or is null");
      return;
    }

    console.log("totalRecountCount:", this.totalRecountCount);
    console.log("recordCount:", this.recordCount);

    // if(this.totalRecountCount < this.recordCount){
    //    this.recordCount = this.totalRecountCount;
    //    console.log('Updated recordCount:', this.recordCount);
    // }

    this.data = this.items.slice(0, this.recordCount);
    console.log("loadInitialData : " + this.data);

    if (this.totalRecountCount > this.recordCount) {
      this.loadMoreStatus = "Load More";
      console.log("this.loadMoreStatus : " + this.loadMoreStatus);
    }
  }

  //enquiry record stage updated to shortlisted units
  updateEnquiryShortlisted() {
    const recordInput = {
      fields: {
        [ENQUIRY_ID_FIELD.fieldApiName]: this.enquiryId,
        [STAGE_NAME.fieldApiName]: "Shortlist Units"
      }
    };
    updateRecord(recordInput)
      .then(() => {})
      .catch(() => {});
  }

  //method to create property attribute update record
  callApexMethod(selectedRecordIds, varPAUId, activityType) {
    createPAU({ selectedRecordIds, varPAUId, activityType })
      .then((result) => {
        console.log("result:" + result);
      })
      .catch(() => {
        // Handle any errors
      });
  }

  //to open parking modal
  showParkingModal() {
    this.parkingModalClass = "slds-show";
  }

  animateReservationProgress(targetValue, status) {
    this.progressStatus = status;

    return new Promise((resolve) => {
      clearInterval(this.progressTimer);

      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this.progressTimer = setInterval(() => {
        if (this.progressValue >= targetValue) {
          clearInterval(this.progressTimer);

          resolve();

          return;
        }

        this.progressValue++;
      }, 40);
    });
  }

  showReservationProgress() {
    this.showReservationOverlay = true;

    this.progressValue = 10;

    this.progressStatus = "Validating selected units";
  }

  hideReservationProgress() {
    clearInterval(this.progressTimer);

    this.showReservationOverlay = false;

    this.progressValue = 0;

    this.progressStatus = "";
  }

  async createReservation() {
    const createOfferSalesProposalData = {
      enqRecordId: this.enquiryId,

      opportunity: this.opportunityId,

      enquiry: encodeURIComponent(this.enquiryValue),

      selectedIds: this.selectedRecordIds,

      selectedUnitsParkingUnitsMap: this.unitParkingRecordMap
    };

    this.showReservationProgress();

    await this.animateReservationProgress(35, "Checking reservation conflicts");

    try {
      const result = await createOfferWithSelectedUnits({
        createOfferSalesProposalData
      });

      console.log("Offer Created:", result);

      await this.animateReservationProgress(65, "Creating Offer");

      await this.animateReservationProgress(90, "Finalizing");

      await this.animateReservationProgress(100, "Redirecting...");

      // eslint-disable-next-line @lwc/lwc/no-async-operation
      await new Promise((resolve) => setTimeout(resolve, 300));

      this.hideReservationProgress();

      this.showToast("Success", "Reservation created successfully", "success");

      if (this.selectedRecordIds.length > 1) {
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: this.enquiryId ? this.enquiryId : this.opportunityId,
            actionName: "view"
          }
        });
      } else {
        const offerId = result[0];

        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: offerId,
            actionName: "view"
          }
        });
      }
    } catch (error) {
      this.hideReservationProgress();

      let errorMessage = "Error creating Offer";

      if (error?.body?.pageErrors?.length) {
        errorMessage = error.body.pageErrors[0].message;
      } else if (error?.body?.message) {
        errorMessage = error.body.message;
      }

      this.showToast("Error", errorMessage, "error");
    } finally {
      this.isPurchaseLoading = false;
      this.isProceedLoading = false;
    }
  }

  //Salesforce function calls
  showToast(title, message, variant) {
    const toastEvent = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(toastEvent);
  }

  //Used to close search page and go back to enquiry record
  closetab() {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.recordId,
        actionName: "view"
      }
    });
  }

  //Getter method check if there are any units fetched
  get hasData() {
    return this.data && this.data.length > 0;
  }

  closeConflictModal() {
    this.showConflictModal = false;
  }

  async handleProceedWithConflict() {
    this.showConflictModal = false;

    try {
      const unavailableUnits = await validateUnitAvailability({
        unitIds: this.selectedRecordIds
      });

      if (unavailableUnits.length > 0) {
        this.showToast(
          "Error",
          `The following units are no longer available: ${unavailableUnits.join(", ")}`,
          "error"
        );
        return;
      }
    } catch (error) {
      this.showToast(
        "Error",
        error?.body?.message || "Error validating unit availability.",
        "error"
      );
      return;
    }

    this.isProceedLoading = true;

    this.handlePromotionFlow();
  }

  handlePromotionFlow() {

    if (this.unitSearchTableConfiguration[0]?.pflexmet__Show_Promo_Configuration__c && this.selectedRecordIds.length > 1) {
      this.isPurchaseLoading = false;
      this.showPromotionPrompt = true;

      console.log("records: ", JSON.stringify(this.records, null, 2));
      console.log(
        "selected record ids: ",
        JSON.stringify(this.selectedRecordIds, null, 2)
      );
      console.log("enquiry id: ", this.enquiryId);
      console.log("opportunity id: ", this.opportunityId);
      console.log(
        "unitParkingRecordMap",
        JSON.stringify(this.unitParkingRecordMap, null, 2)
      );
    } else {
      this.createReservation();
    }
  }

  handleSkipPromotion() {
    this.showPromotionPrompt = false;
    this.createReservation();
  }

  handleConfigureOffer() {
    this.showPromotionPrompt = false;
    this.showOfferConfiguration = true;
  }

  handleCancel() {
    this.showOfferConfiguration = false;
  }
}