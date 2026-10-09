import LightningModal from 'lightning/modal';
import { api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPaymentPlans from '@salesforce/apex/OfferConfigurationController.getPaymentPlans';
import createConfiguredOffers from '@salesforce/apex/OfferConfigurationController.createConfiguredOffers';

export default class OfferConfigurationModal extends LightningModal {
    @api units = [];
    @api enquiryId;
    @api opportunityId;

    activeUnitId;
    plansByUnit = {};          // unitId -> Payment_Plan_template__c[]
    selectedPlanByUnit = {};   // unitId -> planId
    isLoading = false;
    isSaving = false;

    connectedCallback() {
        const selected = {};
        (this.units || []).forEach((u) => {
            selected[u.id] = u.defaultPaymentPlanId || null;
        });
        this.selectedPlanByUnit = selected;
        if (this.units && this.units.length) {
            this.activateUnit(this.units[0].id);
        }

        console.log('units from modal: ', JSON.stringify(this.units, null, 2));
    }

    async activateUnit(unitId) {
        this.activeUnitId = unitId;
        if (this.plansByUnit[unitId]) return;
        this.isLoading = true;
        try {
            const plans = await getPaymentPlans({ unitId });
            this.plansByUnit = { ...this.plansByUnit, [unitId]: plans };

            console.log('hey ppis here: ', JSON.stringify(this.plansByUnit, null, 2));
        } catch (e) {
            this.toast('Error', this.errMsg(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get activePlans() {
        return this.plansByUnit[this.activeUnitId] || [];
    }

    get noPlans() {
        return !this.isLoading && this.activeUnitId && this.activePlans.length === 0;
    }

    get unitCards() {
        return (this.units || []).map((u) => {
            const plans = this.plansByUnit[u.id] || [];
            const plan = plans.find((p) => p.Id === this.selectedPlanByUnit[u.id]);
            return {
                ...u,
                planName: plan ? plan.Name : this.selectedPlanByUnit[u.id] ? 'Default plan' : 'Not selected',
                cssClass: 'unit-card' + (u.id === this.activeUnitId ? ' selected' : '')
            };
        });
    }

    get planCards() {
        const selectedId = this.selectedPlanByUnit[this.activeUnitId];
        return this.activePlans.map((p) => ({
            id: p.Id,
            name: p.Name,
            cssClass: 'payment-card' + (p.Id === selectedId ? ' selected' : '')
        }));
    }

    get selectedPlanItems() {
        const plan = this.activePlans.find(
            (p) => p.Id === this.selectedPlanByUnit[this.activeUnitId]
        );
        const items = plan && plan.pflexmet__Template_Items1__r;
        if (!items) return [];

        return items.map((i) => ({
            id: i.Id,
            name:
                i.pflexmet__Payment_Item_Master__r?.Name ||
                i.pflexmet__Item_Name__r?.Name ||
                "-",
            itemType: i.pflexmet__Item_Name__r?.Name || "-",
            percentage:
                i.pflexmet__Percentage__c != null
                    ? `${i.pflexmet__Percentage__c}%`
                    : "-",
            basedOn: i.pflexmet__Payment_Based_On__c || "-",
            milestone: i.pflexmet__Milestone__r?.Name || "-",
            dueDate: i.pflexmet__Tentative_Due_Date__c
        }));
    }

    get createButtonLabel() {
        return this.isSaving ? 'Creating...' : 'Create Offer';
    }

    handleUnitClick(event) {
        this.activateUnit(event.currentTarget.dataset.id);
    }

    handlePlanClick(event) {
        this.selectedPlanByUnit = {
            ...this.selectedPlanByUnit,
            [this.activeUnitId]: event.currentTarget.dataset.id
        };
    }

    async handleCreateOffer() {
        if (this.isSaving) return;
        this.isSaving = true;
        const payload = {
            selectedUnitIds: this.units.map((u) => u.id),
            enquiryId: this.enquiryId || null,
            opportunityId: this.opportunityId || null,
            unitConfigEntries: this.units.map((u) => ({
                unitId: u.id,
                selectedPaymentPlanId: this.selectedPlanByUnit[u.id] || null
            }))
        };
        try {
            const offerIds = await createConfiguredOffers({ dataJson: JSON.stringify(payload) });
            this.toast('Success', `${offerIds.length} offer(s) created`, 'success');
            this.close(offerIds);
        } catch (e) {
            this.toast('Error', this.errMsg(e), 'error');
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.close();
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errMsg(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Something went wrong';
    }
}