public class OpportunityTriggerHandler {

    
    Public static void createOpportunityDefaultFolderInSharePoint(List<Opportunity>oppListNew)
    {
        for(Opportunity opp:oppListNew)
        {
            Id recId= opp.Id;
            FilesBiSyncController.createDefaultFoldersFromTrigger(recId); 
        }
    }
}