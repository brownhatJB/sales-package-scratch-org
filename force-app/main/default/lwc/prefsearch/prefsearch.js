/**
 * @module             : Real_Estate_Module
 * @description        : LWC component used to show units which satisfy the unit preference set in the record.
 * @namespace          :
 * @author             : SREERAM.R
 * @group              : Unit Search
 * @last modified on   : 29-09-2026
 * @last modified by   : Jouhar C
 **/
import { LightningElement, wire, track, api } from "lwc";

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

const URL_FILTER_MAP = {
  c__propertyId: "pflexmet__Properties__c",
  c__unitType:   "pflexmet__Type__c",
  c__view:       "pflexmet__View__c",
  c__bedrooms:   "pflexmet__Bedrooms__c",
  c__maxAmt:     "pflexmet__Unit_Price__c",
  c__maxarea:    "pflexmet__Total_Area__c",
  c__floor:      "pflexmet__Floor__c"
};

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
  @track FilterValues = {};
  @track urlFilterValues = {};

  @track displayedFields = [];

  queryFields = "";

  @track selectedRecordIds = [];
  @track data = [];
  @track items = [];
  @track recordCount = 20;
  @track loadMoreStatus = "";
  @track totalRecountCount = 0;

  @api recordId;
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
  @wire(getFieldSet, {
      sObjectName: "pflexmet__Units__c",
      fieldSetName: "pflexmet__Unit_Search",
      recordId: "$prefId"
  })
  wiredFields({ error, data }) {
      if (data) {
          const fieldSetData = JSON.parse(data);

          const cols = [];
          const fields = [];

          fieldSetData.forEach((currentItem) => {
              // Build the SELECT field list
              if (
                  currentItem.name &&
                  !fields.includes(currentItem.name)
              ) {
                  fields.push(currentItem.name);
              }

              // Build the table columns
              let col;

              if (currentItem.label === "Property Picture") {
                  col = {
                      label: "Property Picture",
                      type: "customPictureType",
                      typeAttributes: {
                          pictureUrl: {
                              fieldName: "propertyImage__c"
                          }
                      },
                      cellAttributes: {
                          alignment: "center"
                      }
                  };
              } else {
                  col = {
                      label: currentItem.label,
                      fieldName: currentItem.name
                  };
              }

              cols.push(col);
          });

          this.columns = cols;

          // Store the field list
          this.displayedFields = fields;

          // Convert the array into a comma-separated string
          this.queryCreation(this.displayedFields);

          console.log(
              "Displayed fields:",
              JSON.stringify(this.displayedFields)
          );

          console.log(
              "queryFields:",
              this.queryFields
          );
      } else if (error) {
          console.error("Error loading field set:", error);

          this.error = error;
          this.columns = undefined;
      }
  }

  queryCreation(value) {
      this.queryFields = value.join(", ");
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
      console.log('heyyy units here: ', JSON.stringify(this.records, null, 2));
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.records = undefined;
    }
  }

  //get page reference values passed from detail page button from which this lwc page is opened
  @wire(CurrentPageReference)
  wiredPageRef(pageRef) {
    if (pageRef) {
      const state = pageRef.state || {};
      this.enquiryId = state.c__enqRecordId;
      this.opportunityId = state.c__oppRecordId;
      this.prefId = state.c__prefRecordId || null;

      const urlFilters = {};
      Object.keys(URL_FILTER_MAP).forEach((param) => {
        const v = state[param];
        if (v !== undefined && v !== null && v !== "") {
          urlFilters[URL_FILTER_MAP[param]] = v;
        }
      });
      this.urlFilterValues = urlFilters;
      console.log('url filters from page reference:', JSON.stringify(this.urlFilterValues, null, 2));
    }
  }

  //get units to be displayed
  loadUnits() {
    // Do not call Apex until the field list is ready
    if (!this.queryFields) {
        console.warn(
            "Cannot load units: queryFields is empty."
        );
        return;
    }

    console.log(
        "Sending filters:",
        JSON.stringify(this.FilterValues)
    );

    console.log(
        "Sending queryFields:",
        this.queryFields
    );

    getunits({
        filterJson: JSON.stringify(this.FilterValues),
        fields: this.queryFields
    })
    .then((result) => {
        console.log(
            "Units returned from Apex:",
            JSON.stringify(result, null, 2)
        );

        this.processData(result);
        this.error = undefined;
    })
    .catch((error) => {
        console.error(
            "Error loading units:",
            JSON.stringify(error)
        );

        this.error = error;
        this.data = [];
        this.items = [];
        this.totalRecountCount = 0;
        this.loadMoreStatus = "";
    });
  }

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
    console.log(
        "Filter event received:",
        JSON.stringify(event.detail, null, 2)
    );

    // The child filter component now sends the complete
    // dynamic filter structure.
    this.FilterValues = event.detail || {};

    console.log(
        "FilterValues:",
        JSON.stringify(this.FilterValues, null, 2)
    );

    this.loadUnits();
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

  processData(data) {
    const result = JSON.parse(JSON.stringify(data));

    this.totalRecountCount = result.length;
    this.items = result;

    // Reset to first page whenever Apex data changes
    this.recordCount = 20;

    this.loadInitialData();
  }

  handleLoadMore() {
    this.recordCount += 20;

    if (this.recordCount < this.totalRecountCount) {
        this.data = this.items.slice(0, this.recordCount);
        this.loadMoreStatus = "Load More";
    } else {
        this.data = this.items.slice(0, this.totalRecountCount);
        this.loadMoreStatus = "";
    }
  }

  loadInitialData() {
    this.data = this.items.slice(0, this.recordCount);

    if (this.totalRecountCount > this.recordCount) {
        this.loadMoreStatus = "Load More";
    } else {
        this.loadMoreStatus = "";
    }
  }
}