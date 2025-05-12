@isTest
public class OpportunityTriggerHandlerTest {
    
    @testSetup
    public static void testData()
    {
        
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        Id StoryRecordTypeId = Schema.SObjectType.Task__c.getRecordTypeInfosByName().get('Task').getRecordTypeId();
        
        Resource__c resource=new Resource__c();
        resource.Name='testresource';
        resource.Email__c=userinfo.getUserEmail();
        resource.WinfomiMail__c='dev@winfomi.com';
        resource.Employment_Type__c='permanent';
        resource.Status__c='Active';
        resource.Skill__c='custom UI';
        resource.Mobile_Number__c='9898989898';
        insert resource;
        
        Project__c pro=new Project__c();
        pro.Name='TestProject';
        insert pro;
        
        list <Project__c> projectList=new list <Project__c>([select id from Project__c Limit 1]);
        list <Resource__c> ResourceList=new list <Resource__c>([select id from Resource__c Limit 1]);
        
        
        Task__c tas =new Task__c();
        tas.TaskName__c='Test';
        tas.Total_Spent_Effort__c=0;
        tas.Project__c=projectList.get(0).id;
        tas.Stage__c = 'Planning';
        tas.Task_Owner__c=ResourceList.get(0).Id;
        tas.RecordTypeId=StoryRecordTypeId;
        tas.Do_not_create_Sub_Tasks__c=True;
        tas.Do_not_Create_Default_Developer_Task__c=true;
        tas.Description__c='t';
        tas.Exp_Testing_Completion_Date__c=system.today();
        tas.Est_Testing_Effort__c=0;
        tas.Milestone__c=null;
        tas.Start_Date__c=system.today();
        tas.Primary_Tester__c=ResourceList.get(0).Id;
        tas.Exp_Review_Completion_Date__c=system.today();
        tas.Est_Review_Effort__c=3;
        tas.Primary_Supervisor__c=ResourceList.get(0).Id;
        insert tas;
    } 
    
    
    public static testMethod void testRunAs() {
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        Account testAccount = new Account();
        testAccount.name='test1';
        testAccount.Industry='Others';
        testAccount.Phone='999999999';
        insert testAccount;
        
        Contact con =new Contact();
        con.Lastname='test';
        con.LeadSource='Other';
        insert con;
        
        opportunity opp=new opportunity();
        opp.AccountId=testAccount.Id;
        opp.Name='Test1';
        opp.Contact__c=con.Id;
        opp.FilesBiSync_Folder_Id__c='test';
        opp.StageName='Appointment';
        opp.LeadSource='Advertisement';
        opp.ExpectedHour__c=2.00;
        opp.CloseDate=date.parse('01/01/2023');
        insert opp;
        
        List<Project__c> prList=new list<Project__c>([select id, name,Total_Task_Spent_Effort__c,Total_Task_Agreed_Effort__c
                                                      from project__c limit 1]);
        
        Task__c tsk=new Task__c();
        
        tsk.TaskName__c='Test 1';
        tsk.Project__c=prList.get(0).Id;
        tsk.Opportunity__c=opp.Id;
        tsk.Do_not_create_Sub_Tasks__c=True;
        tsk.Do_not_Create_Default_Developer_Task__c=true;
        tsk.Total_Spent_Effort__c=9;
        tsk.Agreed_Effort__c=4;
        tsk.Stage__c='Completed';
        tsk.EstPenEffortManual__c=2;
        
        insert tsk;
        
    }   
}