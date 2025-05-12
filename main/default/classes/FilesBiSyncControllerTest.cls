@isTest
public class FilesBiSyncControllerTest {
    
    
    @testSetup
    public static void testData(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        Account testAccount = new Account();
        testAccount.name='test';
       // testAccount.Market__c='Education';
        testAccount.Industry='Others';
        testAccount.Phone='999999999';
        insert testAccount;
        
        opportunity opp=new opportunity();
        opp.AccountId=testAccount.Id;
        opp.Name='Test%';
       // opp.Group__c='Education';
        opp.ExpectedHour__c=2.0;
        opp.StageName='Appointment';
        opp.LeadSource='Advertisement';
        opp.CloseDate=date.parse('01/01/2023');
        insert opp;
        
        Blob body=blob.valueOf('Test Document');
        ContentVersion conVer = new ContentVersion();
        conVer.ContentLocation = 'S';
        conVer.PathOnClient = 'Name.Pdf';
        conVer.Title = 'Name.Pdf';
        conVer.VersionData = Body;
        
        insert conVer;
        List<ContentVersion> cvList = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :conVer.Id];
        
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.LinkedEntityId = opp.Id;
        cdl.ContentDocumentId = cvList[0].ContentDocumentId;
        cdl.shareType = 'V';
        insert cdl;          
    }
    
    @isTest
    public static void testMethod1(){
        
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        Test.startTest();
        Account testAccount = new Account();
        testAccount.name='test1';
     //   testAccount.Market__c='Education';
        testAccount.Industry='Others';
        testAccount.Phone='999999999';
        insert testAccount;
        
        opportunity opp=new opportunity();
        opp.AccountId=testAccount.Id;
        opp.Name='Test1';
    //    opp.Group__c='Education';
        opp.ExpectedHour__c=2.0;
        opp.FilesBiSync_Folder_Id__c='test';
        opp.StageName='Appointment';
        opp.LeadSource='Advertisement';
        opp.CloseDate=date.parse('01/01/2023');
        insert opp;
        
        FilesBiSyncController.getDetails(opp.Id);
        String targetUri='Shared Documents/Salesforce/Opportunity/Test Opp 1/Test Folder 1';
        targetUri=targetUri.replace(' ','%20' );
        string tes='\''+targetUri+'\'';
        string uri='https://jmcltd.sharepoint.com/sites/Org/_api/web/getfolderbyserverrelativeurl('+tes+')?$expand=Folders/ListItemAllFields/FieldValuesAsText,Files/ListItemAllFields/FieldValuesAsText';
        Test.stopTest();
        //  FilesBiSyncController.getSharePointFilesAndFolders(uri);
    }
    
    @isTest
    public static void testMethod2(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        String targetUri='Shared Documents/Salesforce/Opportunity/Test Opp 1/Test Folder 1';
        targetUri=targetUri.replace(' ','%20' );
        string tes='\''+targetUri+'\'';
        string uri='https://jmcltd.sharepoint.com/sites/Org/_api/web/getfolderbyserverrelativeurl('+tes+')?$expand=Folders/ListItemAllFields/FieldValuesAsText,Files/ListItemAllFields/FieldValuesAsText';
        
        FilesBiSyncController.getSharePointFilesAndFolders(uri);
    }
     @isTest
    public static void testRootFolder(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        Opportunity opp=[SELECT Id,Name,FilesBiSync_Folder_Id__c From Opportunity Where Name='Test%' LIMIT 1];
        Test.startTest();
        FilesBiSyncController.getRootFolderDetails(opp.FilesBiSync_Folder_Id__c+'/test');
        Test.stopTest();
    } 
    @isTest
    public static void testMethod3(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        String FolderUri='https://jmcltd.sharepoint.com/sites/Org/Shared Documents/Salesforce/Opportunity/City of Penticton-HD Shelving 0061Q00000zeiTGQAY/Test Folder 1';
        String FolderName='Test Folder Apex%';
        FolderUri=FolderUri.replace(' ','%20');
        FilesBiSyncController.createFolder(FolderUri ,FolderName);
        
    }
    @isTest
    public static void testMethod4(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        String FolderUri='https://jmcltd.sharepoint.com/sites/Org/Shared Documents/Salesforce/Opportunity/City of Penticton-HD Shelving 0061Q00000zeiTGQAY/Test Folder 1/Test Folder Apex';
        
        FolderUri=FolderUri.replace(' ','%20');
        Test.startTest();
        FilesBiSyncController.deleteFolder(FolderUri );
        Test.stopTest();
        
    }
    @isTest
    public static void testMethod5(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        String FolderUri='https://jmcltd.sharepoint.com/sites/Org/Shared Documents/Salesforce/Opportunity/City of Penticton-HD Shelving 0061Q00000zeiTGQAY/Test Folder 1/Rename Apex Test';
        String Rename='Rename Apex%';
        FolderUri=FolderUri.replace(' ','%20');
        FilesBiSyncController.updateFolder(FolderUri ,Rename);
    }
     @isTest
    public static void testMethodUpdateolderByID(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        String FolderUri='https://jmcltd.sharepoint.com/sites/Org/Shared Documents/Salesforce/Opportunity/City of Penticton-HD Shelving 0061Q00000zeiTGQAY/Test Folder 1/Rename Apex Test';
        String Rename='Rename Apex%';
        FolderUri=FolderUri.replace(' ','%20');
        FilesBiSyncController.updateFolderById(FolderUri ,Rename);
    }
     @isTest
    public static void testMethodSearch(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        String searchString='Search';
        FilesBiSyncController.sharepointSearch(searchString);
    }
    @isTest
    public static void testMethodMoveFolder(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        String source='Search';
        String dest='Dest';
        Test.startTest();
        FilesBiSyncController.moveFolder(source,dest);
         Test.stopTest();
    }
    @isTest
    public static void testMethodCreateFile(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        String Name='Name';
        String Uri='TestURI';
        Test.startTest();
        FilesBiSyncController.createFile(Uri,Name);
         Test.stopTest();
    }
    
    @isTest
    public static void testMethod6(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        List<ContentVersion> cvList = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Title = :'Name.Pdf'];
        
        String FolderUri='https://jmcltd.sharepoint.com/sites/Org/Shared Documents/Salesforce/Opportunity/City of Penticton-HD Shelving 0061Q00000zeiTGQAY/Test Folder 1';
        FolderUri=FolderUri.replace(' ','%20');
        
        
        List<String> idList = new list<String>();
        idList.add(cvList[0].Id);
        FilesBiSyncController.uploadFiles(FolderUri,idList);
    }
    @isTest
    public static void testDeleteFile(){
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        String FolderUri='https://jmcltd.sharepoint.com/sites/Org/Shared Documents/Salesforce/Opportunity/City of Penticton-HD Shelving 0061Q00000zeiTGQAY/Test Folder 1/test dem.txt';
        String FolderUri1='https://jmcltd.sharepoint.com/sites/Org/Shared Documents/Salesforce/Opportunity/City of Penticton-HD Shelving 0061Q00000zeiTGQAY/Test Folder 1/Test demo.txt';
        FolderUri=FolderUri.replace(' ','%20');
        FolderUri1=FolderUri1.replace(' ','%20');
        List<String> stringList=new List <String>();
        stringList.add(FolderUri);
        stringList.add(FolderUri1);
        Test.startTest();
        FilesBiSyncController.deleteFile(FolderUri );
        Test.stopTest();
        
    }
    @isTest
    public static void testMethod8(){
        
        Opportunity opp=[SELECT Id,Name From Opportunity Where Name='Test%' LIMIT 1];
        Id recId=opp.Id;
        String FolderUri='https://jmcltd.sharepoint.com/sites/Org/Shared Documents/Salesforce/Opportunity/City of Penticton-HD Shelving 0061Q00000zeiTGQAY/Test Folder 1';
        FolderUri=FolderUri.replace(' ','%20');
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        Test.startTest();
        FilesBiSyncController.createTemplate(FolderUri,recId);
        Test.stopTest();
        
    }
    @isTest
    public static void testMethodGetTemplate(){
        
        Opportunity opp=[SELECT Id,Name From Opportunity Where Name='Test%' LIMIT 1];
        Id recId=opp.Id;
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        Test.startTest();
        FilesBiSyncController.getTemplateDetails(recId);
        Test.stopTest();
        
    }
    @isTest
    public static void testMethod9(){
        
        Opportunity opp=[SELECT Id,Name From Opportunity Where Name='Test%' LIMIT 1];
        Id recId=opp.Id;
        
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        Test.startTest();
        FilesBiSyncController.createDefaultFolders(recId);
        Test.stopTest();
        
    } 
    @isTest
    public static void testMethod10(){
        Test.StartTest();
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        FilesBiSyncAuth sh1 = new FilesBiSyncAuth();
        String sch = '0 0 23 * * ?'; system.schedule('Test Check', sch, sh1); Test.stopTest(); 
        
    }
 /*   @isTest
    public static void filesBiSyncHelperTest(){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
        
        Lead lead = new Lead();
        lead.FirstName = 'finlite';
        lead.LastName = 'techno test';
        lead.Company = 'Finlite Techno PVT LTD';
        lead.Title = 'pathik test';
        lead.LeadSource = 'Advertisement';
        lead.Status = 'New';
        lead.Lead_Source_Description__c = 'other desc';
        lead.Market__c = 'Education';
        lead.Industry = 'Office';
        lead.State = 'Gujarat';
        lead.Phone = '9033427787';
        lead.Group__c = 'Education';
        lead.Website = 'Test.com';
        lead.Opportunity_Name__c = 'Test';
        insert lead;
        
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(lead.id);
        lc.setDoNotCreateOpportunity(false);
        lc.setOpportunityName('Test');
        lc.setConvertedStatus(convertStatus.MasterLabel);
        Database.LeadConvertResult lcr = Database.convertLead(lc);

        Opportunity opp = new Opportunity();
        opp.Id=lcr.getOpportunityId();
        opp.FilesBiSync_Folder_Id__c='test';
        opp.Target_Completion_Date__c = system.today()+10;
        opp.StageName = 'Closed Won';
        opp.Estimated_Shipping_Email_Sent__c = system.now();
        opp.Tracking_Email_Sent__c = system.now();
        opp.Group__c = 'General Public';
        opp.CloseDate = System.Today();
        opp.StageName = 'Appointment';
        opp.LeadSource= 'website';
        opp.PriceBook2Id = '01s36000000bcwQAAQ';
        opp.Billing_Contact__c = lcr.getContactId();
        opp.Receiving_Contact__c = lcr.getContactId();
        opp.PROJ_Client_PO__c = '123';
        opp.Deposit__c = 123;
        update opp;
        Test.stopTest();
    }
    @isTest 
    Public static void opportunityTest(){
       
        Account acc= new Account();
        acc.Name = 'Black Stool Account Test';
        acc.Market__c = 'General Public';
        acc.Industry = 'Other';
        acc.Phone = '12345674898';
        insert acc;
        
        Supplier__c su=new Supplier__c();
        su.name='Black Stool Account Test';
        su.Type__c='Architect'; 
        su.Currency__c='US Dollar';
        su.Vendor_Buying_Discount__c = 12;
        su.Brokerage_Fees__c= 12;
        su.Freight_Charge__c= 5;
        su.Duty__c = 9;
        su.Country__c='ret';
        su.Telephone__c='1234567890';
        insert su;
        
        Product2 pro=new Product2();
        pro.RecordTypeId='012360000003rm4';
        pro.Name='Black Stool Product Test';
        pro.ProductCode='BlackStoolProductTest';
        pro.SKU__c='587453679548764';
        pro.Supplier__c=su.id;
        pro.Product_image__c ='http://jmc.my.salesforce-sites.com/servlet/rtaImage?eid=01t36000003MXjO&feoid=00N3600000SkWfg&refid=0EM360000003REf';
        pro.Quickbooks_Income_Account__c = '4050 - Service';
        pro.Quickbooks_Expense_Account__c= '5020 - Furniture';
        pro.Quickbooks_Type__c='Service';
        pro.Quickbooks_Asset_Account__c='Non-Inventory';
        pro.Vendor_List_Price__c=20.0;
        pro.Duty__c =2;
        pro.Vendor_Buying_Discount__c =5;
        pro.Product_URL__c='http://finitesting.com/jmcdesigninteriors/chair1.jpg';
        insert pro;
        
        Pricebook2 customPB = new Pricebook2(Name='Standard Price Book', isActive=true);
        insert customPB;
        
        PricebookEntry customPrice = new PricebookEntry( Pricebook2Id = customPB.Id, Product2Id = pro.Id,UnitPrice = 12000, IsActive = true);
        insert customPrice;
        
        Contact contactRecord =new Contact();
        contactRecord.AccountId = acc.Id;
        contactRecord.lastName = 'Hello';
        contactRecord.Market__c ='Supplier';
        contactRecord.JMC_Category__c = 'Preschool';
        contactRecord.Email = 'crive@sd46.bc.ca';
        contactRecord.Title ='Principal';
        contactRecord.Update_with_Account_Billing_Address__c = false;
        insert contactRecord;

        Opportunity opportunityObj = new Opportunity();
        opportunityObj.Name = 'Black Stool Opportunity Test';
        opportunityObj.AccountId = acc.id;
        opportunityObj.Group__c = 'General Public';
        opportunityObj.CloseDate = System.Today();
        opportunityObj.StageName = 'Appointment';
        opportunityObj.LeadSource= 'website';
        opportunityObj.PriceBook2Id = '01s36000000bcwQAAQ';
        opportunityObj.Billing_Contact__c = contactRecord.id;
        opportunityObj.Receiving_Contact__c = contactRecord.id;
        opportunityObj.PROJ_Client_PO__c = '123';
        opportunityObj.Deposit__c = 123;
        opportunityObj.Ordering_Contact__c = contactRecord.Id;

        
        insert opportunityObj;
        
        OpportunityLineItem opportunityLineItems = new OpportunityLineItem();
        opportunityLineItems.Product2Id =  pro.Id;
        opportunityLineItems.OpportunityId = opportunityObj.Id;
        opportunityLineItems.Quantity = 2;
        opportunityLineItems.UnitPrice = 5;
        opportunityLineItems.Quickbooks_Override_Class__c = '4047 - PPS (Project Public Space)';
        opportunityLineItems.QB_Tax_Description__c = 'GST';
        opportunityLineItems.Image_to_Use__c = 'Image #1';
        System.debug('T-OLI Quantity-'+opportunityLineItems.Quantity);
        insert opportunityLineItems;
        
        Inventory__c inventoryRecord =  new Inventory__c();
      //  inventoryRecord.Name = 'Black Stool Product Test Inventory';
        inventoryRecord.Product_Name__c = 'Black Stool Product Test';
        inventoryRecord.Product_Code__c ='BlackStoolProductTest';
        inventoryRecord.Product__c =pro.Id;
        inventoryRecord.Quantity__c = 5;
        inventoryRecord.Physicalstock__c = 5;
        inventoryRecord.Sold_stock__c = 5;
        Insert inventoryRecord;

        Quote testQuote = new Quote(
                OpportunityId = opportunityObj.Id,
                Name = 'test quote'
            );
            insert testQuote;  
        
            JMC_Vendor_PO__c po = new JMC_Vendor_PO__c();
        po.Name = 'Black Stool PO';
        po.Supplier__c = su.Id;
        po.Related_Project__c = opportunityObj.Id;
        po.Carrier_Tracking_Link__c = 'Test';
        po.Estimated_Shipping_Date_from_Supplier__c =system.today();
        System.debug('T-OldOpp'+ po.Related_Project__c);
        insert po;
        
           
     Opportunity opp = [select id from opportunity where name='Black Stool Opportunity Test' limit 1];
     opp.Target_Completion_Date__c = system.today()+10;
     opp.StageName = 'Closed Won';
        opp.Estimated_Shipping_Email_Sent__c = system.now();
        opp.Tracking_Email_Sent__c = system.now();
     Test.startTest();
       Test.setMock(HttpCalloutMock.class, new FilesBiSyncControllerMock());
     Update opp;
     Test.stopTest();
     Decimal qoo = [select id,Sold_stock__c from Inventory__c limit 1].Sold_stock__c;
     system.assertEquals(5, qoo);
    }
*/
}