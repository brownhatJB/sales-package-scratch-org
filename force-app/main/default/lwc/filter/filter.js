/**
 * @module             : Real_Estate_Module
 * @description        : LWC component used to filter units displayed in unit search component
 * @namespace          :
 * @author             : SREERAM.R
 * @group              : Unit Search
 * @last modified on   : 07-30-2026
 * @last modified by   : SREERAM.R
 **/
import { LightningElement, wire, track, api } from "lwc";

//Salesforce functions

//Apex class
import getFieldSet from "@salesforce/apex/UnitSearchFilterQuery.getFieldSet";

//Salesforce object schema api names

export default class Filter extends LightningElement {
  //Variables
  @api objectRecordId;
  @track displayedFields;
  @track queryFields;
  @track FilterFields = [];
  @track fieldValuesMap = {};
  @track filterMetadataMap = {};
  //Wires

  //get fields in json format to display
  @wire(getFieldSet, {
    sObjectName: "pflexmet__Units__c",
    fieldSetName: "",
    recordId: "$objectRecordId"
  })
  wiredFields({ error, data }) {
    if (data) {
      this.FilterFields = data.map((jsonString) => JSON.parse(jsonString));

      console.log("filter fields JSON: ", JSON.stringify(this.FilterFields, null, 2));

      this.filterMetadataMap = {};

      this.FilterFields.forEach(field => {
          this.filterMetadataMap[field.name] = field;
      });

      console.log("filter fields: ", JSON.stringify(this.FilterFields));
    } else if (error) {
      console.log(error);
    }
  }

  //Events
  handleComboboxChange(event) {
    const fieldName = event.currentTarget.dataset.id;
    const fieldValue = event.detail.value;

    // Handle the combobox change event for the specific field
    console.log(`Combobox changed: ${fieldName} = ${fieldValue}`);
const metadata = this.filterMetadataMap[fieldName];

this.fieldValuesMap[fieldName] = {
    value: fieldValue,
    operator: metadata.operator,
    type: metadata.type
};
    console.log(JSON.stringify(this.fieldValuesMap));
    // You can add your logic here based on the specific combobox that changed
  }

  handleInputChange(event) {
    const fieldName = event.currentTarget.dataset.id;
    const fieldValue = event.target.value;

    // Handle the input change event for the specific field
    console.log(`Input changed: ${fieldName} = ${fieldValue}`);
const metadata = this.filterMetadataMap[fieldName];

this.fieldValuesMap[fieldName] = {
    value: fieldValue,
    operator: metadata.operator,
    type: metadata.type
};
    console.log(JSON.stringify(this.fieldValuesMap));
    // You can add your logic here based on the specific input that changed
  }

  //custom event to pass value to parent component
  search() {
    console.log("SEARCH CLICKED");
    console.log("Filters:", JSON.stringify(this.fieldValuesMap));
    this.dispatchEvent(
      new CustomEvent("search", {
        detail: this.fieldValuesMap,
        bubbles: true,
        composed: true
      })
    );
  }

  // clear filter variable values
  clear() {
    this.FilterFields = this.FilterFields.map((field) => {
      return {
        ...field,
        value: field.options ? null : "" // reset value for combobox and input
      };
    });
    this.template
      .querySelectorAll("lightning-combobox, lightning-input")
      .forEach((element) => {
        element.value = element.options ? null : ""; // clear displayed values
      });
    this.fieldValuesMap = {}; // clear backend values
    this.search(); // Trigger search or any other logic
  }

  queryCreation(value) {
    let fieldString = value.join(", ");
    this.queryFields = fieldString;
  }
}