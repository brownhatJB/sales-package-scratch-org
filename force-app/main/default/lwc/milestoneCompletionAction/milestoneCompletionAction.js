import { LightningElement, api, wire } from 'lwc';

import getMilestone from '@salesforce/apex/MilestoneCompletionActionController.getMilestone';

import updateCompletion from '@salesforce/apex/MilestoneCompletionActionController.updateCompletion';

import { CloseActionScreenEvent } from 'lightning/actions';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

export default class MilestoneCompletionAction extends LightningElement {

    _recordId;

    currentStep = 1;

    milestoneName;

    tentativeDate;

    actualDate;


    selectedDateType;

    newDate = '';

    comments = '';

    isSaving = false;

    @api get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;

        if (value) {
            this.loadMilestone();
        }
    }

    async loadMilestone() {

        try {

            const data = await getMilestone({
                milestoneId: this.recordId
            });

            this.milestoneName = data.milestoneName;
            this.tentativeDate = data.tentativeDate;
            this.actualDate = data.actualDate;

        } catch (error) {

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    get isStepOne() {
        return this.currentStep === 1;
    }

    get isStepTwo() {
        return this.currentStep === 2;
    }

    get headerTitle() {

        if (this.currentStep === 1) {
            return 'Update Completion';
        }

        return 'Update Completion';
    }


    get isTentativeDisabled() {
        return this.actualDate != null;
    }


    get selectedDateLabel() {

        return this.selectedDateType === 'ACTUAL'
            ? 'Actual Completion Date'
            : 'Tentative Completion Date';
    }


    get tentativeOptionClass() {

        let classes = 'date-option';

        if (this.selectedDateType === 'TENTATIVE') {
            classes += ' selected';
        }

        if (this.isTentativeDisabled) {
            classes += ' disabled';
        }

        return classes;
    }


    get actualOptionClass() {

        let classes = 'date-option';

        if (this.selectedDateType === 'ACTUAL') {
            classes += ' selected';
        }

        return classes;
    }


    get isNextDisabled() {

        return !this.selectedDateType;
    }


    get commentLength() {

        return this.comments
            ? this.comments.length
            : 0;
    }


    get isSaveDisabled() {

        return (
            this.isSaving ||
            !this.newDate ||
            !this.comments.trim()
        );
    }


    handleTentativeSelection() {

        if (this.isTentativeDisabled) {
            return;
        }

        this.selectedDateType = 'TENTATIVE';
    }


    handleActualSelection() {

        this.selectedDateType = 'ACTUAL';
    }


    handleNext() {

        if (!this.selectedDateType) {
            return;
        }

        if (this.selectedDateType === 'TENTATIVE') {

            this.newDate = this.tentativeDate || '';

        } else {

            this.newDate = this.actualDate || '';

        }

        this.currentStep = 2;
    }


    handleBack() {

        this.currentStep = 1;
    }


    handleDateChange(event) {

        this.newDate = event.target.value;
    }


    handleCommentsChange(event) {

        this.comments = event.target.value;
    }

    async handleSave() {
        if (this.isSaveDisabled) {
            return;
        }

        this.isSaving = true;

        try {
            await updateCompletion({
                milestoneId: this.recordId,
                dateType: this.selectedDateType,
                newDate: this.newDate,
                comments: this.comments.trim()
            });

            await notifyRecordUpdateAvailable([
                { recordId: this.recordId }
            ]);

            this.showToast(
                'Success',
                `${this.selectedDateLabel} updated successfully.`,
                'success'
            );

            this.dispatchEvent(
                new CloseActionScreenEvent()
            );

        } catch (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {

        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }
}