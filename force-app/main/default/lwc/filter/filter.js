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

  _prefFilterValues = {};
  _appliedKey;

  @api
  get prefFilterValues() {
    return this._prefFilterValues;
  }
  set prefFilterValues(value) {
    console.log('inside prefFilterValues setter, value:', JSON.stringify(value, null, 2));
    this._prefFilterValues = value || {};
    this.applyPrefValues();
  }
  
  applyPrefValues() {
    console.log('inside applyPrefValues, prefFilterValues:', JSON.stringify(this._prefFilterValues, null, 2));
    const incoming = this._prefFilterValues;

    if (!Object.keys(incoming).length || !this.FilterFields.length) {
      this.search();
      return;
    };

    const sig = JSON.stringify(incoming);
    if (this._appliedKey === sig) return;
    this._appliedKey = sig;

    const newMap = {};
    this.FilterFields = this.FilterFields.map((field) => {
      const raw = incoming[field.name];
      if (raw === undefined || raw === null || raw === "") return field;

      let value = String(raw);

      if (field.options) {
        if (!field.options.some((o) => String(o.value) === value)) return field;
      } else if (["DOUBLE", "CURRENCY", "INTEGER", "PERCENT"].includes(field.type)) {
        value = value.replace(/,/g, "");
        if (isNaN(Number(value))) return field;
      }

      newMap[field.name] = {
        value,
        operator: field.operator,
        type: field.type
      };
      return { ...field, value };
    });

    this.fieldValuesMap = { ...this.fieldValuesMap, ...newMap };

    if (Object.keys(newMap).length) {
      this.search(); 
    }
  }

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

      this._appliedKey = undefined;   
      this.applyPrefValues();

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