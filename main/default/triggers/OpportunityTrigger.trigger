trigger OpportunityTrigger on Opportunity (after insert) {

    If(Trigger.isInsert)
    {
        If(Trigger.isAfter)
        {
           // OpportunityTriggerHandler.createOpportunityDefaultFolderInSharePoint(trigger.new);
           FilesBiSyncHelper.createDefaultFolderInSharePoint(trigger.new);
        }
    }
}