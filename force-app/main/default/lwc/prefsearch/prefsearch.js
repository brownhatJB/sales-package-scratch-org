/**
 * @module             : Real_Estate_Module
 * @description        : LWC component used to show units which satisfy the unit preference set in the record.
 * @namespace          :
 * @author             : SREERAM.R
 * @group              : Unit Search
 * @last modified on   : 07-23-2024
 * @last modified by   : Nisha Tony
 **/
import { LightningElement, wire, track } from "lwc";

//Salesforce functions
import { refreshApex } from "@salesforce/apex";
import { updateRecord } from "lightning/uiRecordApi";
import { CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";

//Apex class
import getFieldSet from "@salesforce/apex/UnitSearchFieldListPreferenceSearch.getFieldSet";
import getunits from "@salesforce/apex/UnitsearchDynamicSoql.getunits";
import getSelectedUnits from "@salesforce/apex/GetSelectedUnitsUnitSearch.getSelectedUnits";
import createProposalWithSelectedUnits from "@salesforce/apex/CreateSalesProposal.createProposalWithSelectedUnits";
import createOfferWithSelectedUnits from "@salesforce/apex/CreateOffer.createOfferWithSelectedUnits";

//Salesforce object schema api names
import PARENT_FIELD from "@salesforce/schema/Units__c.Default_Payment_Plan__c";
import ID_FIELD from "@salesforce/schema/Units__c.Id";
import UNIT_NAME_FIELD from "@salesforce/schema/Units__c.Name";
import ENQUIRY_FIELD from "@salesforce/schema/Units__c.Enquiry__c";
import ENQUIRY_ID_FIELD from "@salesforce/schema/Enquiry__c.Id";
import STAGE_NAME from "@salesforce/schema/Enquiry__c.Stage__c";
import OPPORTUNITY_FIELD from "@salesforce/schema/Units__c.Opportunity__c";

//Table columns
const colum = [
  {
    label: "Property Picture",
    type: "customPictureType",
    typeAttributes: {
      pictureUrl: { fieldName: "propertyImage__c" }
    },
    cellAttributes: {
      alignment: "center"
    }
  },
  { label: "Unit", fieldName: "Name" },
  { label: "Unit Type", fieldName: "Type__c" },
  { label: "Unit View", fieldName: "View__c" },
  { label: "Bedrooms", fieldName: "Bedrooms__c" },
  { label: "Unit Price", fieldName: "Unit_Price__c", type: "Currency" },
  { label: "Property", fieldName: "PropertyName__c" },
  { label: "Total Area", fieldName: "Total_Area__c" },
  { label: "Tax Value", fieldName: "Tax_Value__c", type: "Currency" },
  {
    label: "Total Price",
    fieldName: "Unit_Price_Including_Tax__c",
    type: "Currency"
  }
];
const colums = [
  { label: "Unit", fieldName: "Name" },
  { label: "Unit Price", fieldName: "Unit_Price__c", type: "Currency" },
  {
    label: "Payment Plan Template",
    fieldName: "Default_Payment_Plan__c",
    type: "Lookup"
  }
];

export default class unitsearchtable extends NavigationMixin(LightningElement) {
  //Variables
  fields = [UNIT_NAME_FIELD, PARENT_FIELD];
  column = [
    { label: "Account Name", fieldName: "Name", type: "text" },
    { label: "Industry", fieldName: "Industry", type: "text" },
    {
      label: "Parent Account",
      fieldName: "ParentId",
      type: "lookup",
      relationshipName: "Parent",
      typeAttributes: { placeholder: "Select Parent Account", editable: "true" }
    }
  ];
  columns;
  accounts = [];
  @track FilterValues = {
    unitType: null,
    bedrooms: null,
    minPrice: null,
    maxPrice: null,
    property: null,
    view: null,
    maxArea: null,
    minArea: null,
    floorNumber: null,
    furnishStatus: null,
    unitStatus: null,
    unitName: null
  };
  @track selectedRecordIds = [];
  records;
  wiredRecords;
  error;
  enquiryId;
  opportunityId;
  selectdunitsforpaymentplanset = [];
  prefId;
  cols = colums;
  col = colum;
  visibleProducts = [];
  @track isModalOpen = false;

  //Wires
  //get fields in json format to display
  @wire(getFieldSet, { sObjectName: "Units__c", fieldSetName: "Unit_Search" })
  wiredFields({ error, data }) {
    if (data) {
      data = JSON.parse(data);
      let cols = [];
      data.forEach((currentItem) => {
        let col;
        if (currentItem.label === "Property Picture") {
          col = {
            label: "Property Picture",
            type: "customPictureType",
            typeAttributes: { pictureUrl: { fieldName: "propertyImage__c" } },
            cellAttributes: { alignment: "center" }
          };
        } else {
          col = { label: currentItem.label, fieldName: currentItem.name };
        }
        cols.push(col);
      });
      this.columns = cols;
    } else if (error) {
      console.log(error);
      this.error = error;
      this.columns = undefined;
    }
  }

  //select units according to filter values
  @wire(getSelectedUnits, {
    unitIds: "$selectedRecordIds"
  })
  wiredSelectedUnits(value) {
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

  //get page reference values passed from detail page button from which this lwc page is opened
  @wire(CurrentPageReference) pageRef;

  connectedCallback() {
    this.enquiryId = this.pageRef.state.c__enqRecordId;
    this.opportunityId = this.pageRef.state.c__oppRecordId; 
    if (this.pageRef.state.c__prefRecordId) {
      this.prefId = this.pageRef.state.c__prefRecordId;
      this.FilterValues = {};

      if (this.pageRef.state.c__bedrooms !== "") {
        this.FilterValues.bedrooms = this.pageRef.state.c__bedrooms;
      }
      console.log("bedrooms:", this.FilterValues.bedrooms);
      if (this.pageRef.state.c__unitType !== "") {
        this.FilterValues.unitType = this.pageRef.state.c__unitType;
      }
      if (this.pageRef.state.c__propertyId !== "") {
        this.FilterValues.property = this.pageRef.state.c__propertyId;
      }
      if (this.pageRef.state.c__view !== "") {
        this.FilterValues.view = this.pageRef.state.c__view;
      }
      if (this.pageRef.state.c__floor !== "") {
        this.FilterValues.floorNumber = this.pageRef.state.c__floor;
      }
      if (this.pageRef.state.c__minArea !== "") {
        this.FilterValues.minArea = parseInt(
          this.pageRef.state.c__minArea.replace(/,/g, ""),
          10
        );
      }
      if (this.pageRef.state.c__maxarea !== "") {
        this.FilterValues.maxArea = parseInt(
          this.pageRef.state.c__maxarea.replace(/,/g, ""),
          10
        );
      }
      if (this.pageRef.state.c__minAmt !== "") {
        this.FilterValues.minPrice = parseFloat(
          this.pageRef.state.c__minAmt.replace(/[$,]/g, "")
        );
        if (!isNaN(this.FilterValues.minPrice)) {
          console.log("minPrice:", this.FilterValues.minPrice);
        } else {
          console.error(
            "Invalid currency value:",
            this.pageRef.state.c__minAmt
          );
        }
      }
      if (this.pageRef.state.c__maxAmt !== "") {
        this.FilterValues.maxPrice = parseFloat(
          this.pageRef.state.c__maxAmt.replace(/[$,]/g, "")
        );
        if (!isNaN(this.FilterValues.maxPrice)) {
          console.log("maxPrice:", this.FilterValues.maxPrice);
        } else {
          console.error(
            "Invalid currency value:",
            this.pageRef.state.c__maxAmt
          );
        }
      }
      console.log("FilterValues : " + JSON.stringify(this.FilterValues));
    }
  }

  //get units to be displayed
  @wire(getunits, {
    filterValues: "$FilterValues"
  })
  mydata;

  //Events
  //handles visible units
  sliceHandler(event) {
    this.visibleProducts = [...event.detail.records];
  }

  //get selected units id
  handleRowSelection(event) {
    const selectedRows = event.detail.selectedRows;
    this.selectedRecordIds = [];
    selectedRows.forEach((row) => {
      this.selectedRecordIds.push(row.Id);
    });
  }

  //pass filter values to variables
  searchfilter(event) {
    if (event.detail.property) {
      this.FilterValues = {
        property: event.detail.property
      };
    } else {
      this.FilterValues = {
        property: null
      };
    }
    if (event.detail.type) {
      this.FilterValues = {
        type: event.detail.type
      };
    } else {
      this.FilterValues = {
        type: null
      };
    }
    if (event.detail.view) {
      this.FilterValues = {
        view: event.detail.view
      };
    } else {
      this.FilterValues = {
        view: null
      };
    }
    if (event.detail.pricemax) {
      this.FilterValues = {
        pricemax: event.detail.pricemax
      };
    } else {
      this.FilterValues = {
        pricemax: 987456123
      };
    }
    if (event.detail.pricemin) {
      this.FilterValues = {
        pricemin: event.detail.pricemin
      };
    } else {
      this.FilterValues = {
        pricemin: 0
      };
    }
    if (event.detail.areamax) {
      this.FilterValues = {
        areamax: event.detail.areamax
      };
    } else {
      this.FilterValues = {
        areamax: 987456123
      };
    }
    if (event.detail.areamin) {
      this.FilterValues = {
        areamin: event.detail.viewareamin
      };
    } else {
      this.FilterValues = {
        areamin: 0
      };
    }
    if (event.detail.floor) {
      this.FilterValues = {
        floor: event.detail.floor
      };
    } else {
      this.FilterValues = {
        floor: null
      };
    }
    if (event.detail.bedroom) {
      this.FilterValues = {
        bedroom: event.detail.bedroom
      };
    } else {
      this.FilterValues = {
        bedroom: null
      };
    }
    if (event.detail.furnished) {
      this.FilterValues = {
        furnished: event.detail.furnished
      };
    } else {
      this.FilterValues = {
        furnished: null
      };
    }
    if (event.detail.name) {
      this.FilterValues = {
        name: event.detail.name
      };
    } else {
      this.FilterValues = {
        unit: null
      };
    }
  }

  //close unit search and redirect to enquiry
  closetab() {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.prefId,
        actionName: "view"
      }
    });
  }

  //shortlist unit and redirect to enquiry
  handleClick () {
    if (this.selectedRecordIds.length === 0) {
      this.showToast(
        "Warning",
        "Please select at least 1 unit to proceed",
        "warning"
      );
      return;
    }
    const recordInputs = this.selectedRecordIds.map((itemId) => {
      const fields = {};
      fields[ID_FIELD.fieldApiName] = itemId;
      fields[ENQUIRY_FIELD.fieldApiName] = this.enquiryId;
      fields[OPPORTUNITY_FIELD.fieldApiName] = this.opportunityId;
      return { fields };
    });
    // alert(JSON.stringify(recordInputs));
    const unitPromises = recordInputs.map((recordInput) =>
      updateRecord(recordInput, { ifUnmodifiedSince: this.lastModifiedDate })
    );
    Promise.all(unitPromises)
      .then(() => {
        this.showToast(
          "Success",
          "Selected Units are shortlisted successfully",
          "success"
        );
        if (this.enquiryId) {
          this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
              recordId: this.enquiryId,
              actionName: "view"
            }
          });
        }
        if (this.opportunityId) {
          this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
              recordId: this.opportunityId,
              actionName: "view"
            }
          });
        }
      })
      .catch(() => {
        this.showToast("Error", "Error shortlisting unit", "error");
      });
    this.updateEnquiryShortlisted();
  }

  //Event to create sales proposal with selected unit and redirect to sales proposal if only one is created and redirect to enquiry if multiple are created
  handleClickProposal () {
    if (this.selectedRecordIds.length <= 0) {
      this.showToast(
        "Warning",
        "Please select at least 1 unit to proceed",
        "warning"
      );
      return;
    }
    const createOfferSalesProposalData = {
      enquiry: "Sales Proposal",
      opportunity : this.opportunityId,
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
      });
  }

  //event to create offer for selected units and redirect to new offer if one one is created and to enquiry if multiple are created
 handlePurchase () {
    if (this.selectedRecordIds.length <= 0) {
      this.showToast(
        "Warning",
        "Please select at least 1 unit to proceed",
        "warning"
      );
      return;
    }
    const createOfferSalesProposalData = {
      enquiry: encodeURIComponent(this.enquiryValue),
      opportunity : this.opportunityId,
      selectedIds: this.selectedRecordIds,
      selectedUnitsParkingUnitsMap: this.unitParkingRecordMap
    };
    createOfferWithSelectedUnits({
      createOfferSalesProposalData: createOfferSalesProposalData
    })
      .then((result) => {
        console.log("Offer Created:", result);
        this.showToast("Success", "Offer created successfully", "success");
        if (this.selectedRecordIds.length > 1) {
          this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
              recordId: this.enquiryId,
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
      })
      .catch((error) => {
        console.error("Error creating Offer:", error);
        this.showToast("Error", "Error creating Offer", "error");
      });
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
    this.isModalOpen = true;
  }

  //close set payment plan option
  closeModal() {
    this.isModalOpen = false;
  }

  //close set payment plan option
  submitDetails() {
    this.isModalOpen = false;
  }

  //Helper methods
  //when unit is shortlisted update enquiry stage to shortlisted
  updateEnquiryShortlisted() {
    const recordInput = {
      fields: {
        [ENQUIRY_ID_FIELD.fieldApiName]: this.enquiryId,
        [STAGE_NAME.fieldApiName]: "Shortlist Units"
      }
    };
    updateRecord(recordInput)
      .then(() => {
        // alert('Enquiry updated successfully.');
        this.showToast(
          "Record Updated",
          "Enquiry record has been updated",
          "success"
        );
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error updating enquiry",
            message: error,
            variant: "error"
          })
        );
      });
  }

  //Salesforce function calls
  //all show toast method
  showToast(title, message, variant) {
    const toastEvent = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(toastEvent);
  }

  //refresh visible products
  Refresh() {
    return refreshApex(this.visibleProducts);
  }

  //refresh wire getting units
  refreshwire() {
    return refreshApex(this.mydata);
  }
}