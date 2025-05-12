public class FilesBiSyncAuth implements Schedulable ,Database.AllowsCallouts{

    public void execute(SchedulableContext sc) {
   
        FilesBiSyncController.authSharePoint();
    }
    
}