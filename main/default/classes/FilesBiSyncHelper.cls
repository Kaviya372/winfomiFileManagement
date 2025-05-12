public class FilesBiSyncHelper {
    
    Public static void createDefaultFolderInSharePoint(List<Opportunity> oppListNew)
    {
        
        for(Opportunity opp1: oppListNew){
            Id recId= opp1.Id;
            if(opp1.FilesBiSync_Folder_Id__c == null){
            FilesBiSyncController.createDefaultFoldersFromTrigger(recId); 
            }
        }
        System.debug('oppnew list:'+oppListNew);
        Map <ID,Lead> convertedLeadMap=new Map<ID,Lead>();
        List<String> oppId=new List<String>();
        for(Opportunity op:oppListNew){
            if(op.FilesBiSync_Folder_Id__c != null){
                FilesBiSyncController outerc = new FilesBiSyncController();
                FilesBiSyncController.moveFolderFromtrigger innerJob = new FilesBiSyncController.moveFolderFromtrigger(op.Id,op.FilesBiSync_Folder_Id__c);
                System.enqueueJob(innerJob);
            }
        }
              
    }
}