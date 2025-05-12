public with sharing class FilesBiSyncController {
    @future(callout=true)
    public static void authSharePoint(){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        String domain = getDomainName(sharePoint.Site_Name__c);
        Boolean isMetadataUpdateNeeded = false;
        HttpRequest httpRequestToSend = new HttpRequest();  
        String requestBody = 'grant_type=client_credentials';
        requestBody += '&client_id='+sharePoint.Client_ID__c+'@'+sharePoint.Tenant_ID__c+'';
        requestBody += '&client_secret='+sharePoint.Client_Secret__c+'';
        System.debug('Client_Secret__c:'+sharePoint.Client_Secret__c);
        requestBody += '&resource=00000003-0000-0ff1-ce00-000000000000/'+domain+'@'+sharePoint.Tenant_ID__c+'';
        httpRequestToSend.setBody(requestBody);
        httpRequestToSend.setMethod('GET');
        httpRequestToSend.setEndpoint('https://accounts.accesscontrol.windows.net/'+sharePoint.Tenant_ID__c+'/tokens/OAuth/2/');
        
        Http http = new Http();  
        HttpResponse httpResponse = new HttpResponse();
        try{
            httpResponse = http.send(httpRequestToSend);  
            
            system.debug('code'+httpResponse.getbody());
            Map<String,Object> responseBody = (Map<String,Object>)JSON.deserializeUntyped(httpResponse.getBody());
            System.debug('responseBody:: '+responseBody); 
            
            //Create a deploy container which will be used for deploying(updating) the Custom Metadata Record
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();       
            if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201) {
                String authToken = String.valueOf(responseBody.get('access_token'));
                //create instance of Metadata.CustomMetadata
                Metadata.CustomMetadata metadataRec =  new Metadata.CustomMetadata();
                metadataRec.fullName = 'File_Storage__mdt.'+sharePoint.DeveloperName;
                metadataRec.label = sharePoint.MasterLabel;
                
                //provide the value for the fields and add it to custom metadata instance
                Metadata.CustomMetadataValue accessTokenToUpdate = new Metadata.CustomMetadataValue();
                accessTokenToUpdate.field = 'SharePoint_Access_Token__c';
                accessTokenToUpdate.value = String.valueOf(responseBody.get('access_token'));
                metadataRec.values.add(accessTokenToUpdate);
                
                mdContainer.addMetadata(metadataRec);
                isMetadataUpdateNeeded = true; 
                if(isMetadataUpdateNeeded && !Test.isRunningTest())
                {
                    Metadata.Operations.enqueueDeployment(mdContainer, null);
                }
            }else{
                String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+httpResponse.getBody());
                sendErrorEmail('get access token', errorMessage);
            }
        }catch(Exception e){
            String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Exeception: '+e.getMessage();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
            sendErrorEmail('get access token', errorMessage);
        }
        
    }
    
    @AuraEnabled
    public static ParentDataWrapper getDetails(Id recordId){
        
        String objectName = String.escapeSingleQuotes(recordId.getSObjectType().getDescribe().getName());
        String sObjectQuery = 'SELECT Id,Name,FilesBiSync_Folder_Id__c FROM '+objectName+' WHERE Id IN (\'' + recordId + '\')';
        List<SObject> sObjectList = Database.query(sObjectQuery);
     
        
        ParentDataWrapper parentDW=new ParentDataWrapper();
        
        Integer row;
        String parentId='';
        String parentLink=''; 
        String accessError='';        
        if(sObjectList.size()>0)
        { 
            try{
                List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                           From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
                File_Storage__mdt sharePoint = fileStorageList[0];
                
               //
                
                String baseFolderPath=sharePoint.Site_Name__c+'Shared Documents/'+sharePoint.Root_Folder__c+'/'+objectName;
                //    String targetUri = 'Shared Documents/'+sharePoint.Root_Folder__c+'/'+objectName+'/'+sObjectList[0].get('Name')+'/';
                //    targetUri=targetUri.replace(' ', '%20');  
                String targetUri = string.valueOf(sObjectList[0].get('FilesBiSync_Folder_Id__c'))+'/'+sObjectList[0].get('Name');
                if(!Test.isRunningTest() && string.isNotBlank(string.valueOf(sObjectList[0].get('FilesBiSync_Folder_Id__c')))){
                    parentDW=FilesBiSyncController.getRootFolderDetails(targetUri);
                }
                else if(!Test.isRunningTest() && string.isBlank(string.valueOf(sObjectList[0].get('FilesBiSync_Folder_Id__c')))){
                    Map<String,Object> response=new Map<String,Object>();
                    String queryValue='.'+string.valueOf(recordId)+'.sfdb';
                    response=FilesBiSyncController.sharepointSearch(queryValue);
                    
                    ///////
                    if(response.size()>0){
                        Map<String,Object> respon1 = (Map<String,Object>)response.get('d');
                        System.debug('respon1:: '+respon1);
                        Map<String,Object> query = (Map<String,Object>)respon1.get('query'); 
                        System.debug('query:: '+query);
                        Map<String,Object> primaryQueryResult = (Map<String,Object>)query.get('PrimaryQueryResult');
                        System.debug('primaryQueryResult:: '+primaryQueryResult);
                        Map<String,Object> relevantResults = (Map<String,Object>)primaryQueryResult.get('RelevantResults');
                        System.debug('relevantResults:: '+relevantResults);
                        
                        
                        row= Integer.valueOf(relevantResults.get('RowCount'));
                        System.debug('row:: '+row);
                        
                        if(row>0)
                        {
                            Map<String,Object> table = (Map<String,Object>)relevantResults.get('Table');
                            System.debug('table:: '+table);
                            Map<String,Object> Rows = (Map<String,Object>)table.get('Rows');
                            System.debug('Rows:: '+Rows);
                            
                            
                            
                            // Get the list of results from the rows
                            List<Object> results = (List<Object>) Rows.get('results');
                            System.debug('results:: '+results);
                            // Loop through each result object
                            for (Object result : results) {
                                Map<String, Object> resultMap = (Map<String, Object>) result;
                                System.debug('resultMap:: '+resultMap);
                                // Get the Cells object from the result
                                Map<String, Object> cells = (Map<String, Object>) resultMap.get('Cells');
                                System.debug('cells:: '+cells);
                                // Get the list of key-value pairs from the Cells object
                                List<Object> cellResults = (List<Object>) cells.get('results');
                                System.debug('cellResults:: '+cellResults);
                                // Loop through each key-value pair object
                                
                                for (Object cellResult : cellResults) {
                                    Map<String, Object> cellResultMap = (Map<String, Object>) cellResult;
                                    System.debug('cellResultMap:: '+cellResultMap);
                                    // Extract the Key, Value, and ValueType properties from the key-value pair object
                                    System.debug('baseFolderPath:: '+baseFolderPath);
                                    if(String.valueOf(cellResultMap.get('Value')) != Null){
                                    if(String.isBlank(parentLink) && String.valueOf(cellResultMap.get('Value')) != Null && String.valueOf(cellResultMap.get('Value')).substringBeforeLast('/')==baseFolderPath && String.valueOf(cellResultMap.get('Key'))=='ParentLink'){
                                        parentLink =string.valueOf(cellResultMap.get('Value'));
                                    }
                                    if(String.isBlank(parentId)&&String.isNotBlank(parentLink)&&String.valueOf(cellResultMap.get('Key'))=='ParentId')
                                    {
                                        parentId=string.valueOf(cellResultMap.get('Value')).removeStart('{').removeEnd('}');
                                        
                                    }
                                    }
                                    
                                    
                                }
                                
                                
                            }
                            
                            String parentFolderName=parentLink.substringAfterLast('/');
                            system.debug('foldername=='+parentFolderName);
                            if(parentFolderName.contains('#')||parentFolderName.contains('"')||parentFolderName.contains('*')||parentFolderName.contains(':')||parentFolderName.contains('<')||parentFolderName.contains('>')||parentFolderName.contains('?')||parentFolderName.contains('/')||parentFolderName.contains('\\\\')||parentFolderName.contains('|')||parentFolderName.contains('%'))
                            {
                                String folderId=FilesBiSyncController.updateFolderById(parentId,parentFolderName);
                                parentId=parentId+'/'+parentFolderName;
                                system.debug('folderId'+folderId);
                                system.debug('parentFolderName'+parentFolderName); 
                            } 
                        }
                        system.debug('parent id'+parentId);
                    }
                    
                    //////
                    
                  
                    if(string.isNotBlank(parentId)){
                        parentId=parentId;
                        parentDW=FilesBiSyncController.getRootFolderDetails(parentId);
                        parentId=parentId.substringBeforeLast('/');
                        sObjectList[0].put('FilesBiSync_Folder_Id__c',parentId);
                        Database.update(sObjectList, false);
                        system.debug('dropbox'+parentId);
                    }
                    else{
                        String folderCreatedID=FilesBiSyncController.createDefaultFolders(String.valueOf(sObjectList[0].get('Id')));
                        if(string.isNotBlank(folderCreatedID))
                        {
                            folderCreatedID=folderCreatedID;
                            parentDW=FilesBiSyncController.getRootFolderDetails(folderCreatedID);
                            folderCreatedID=folderCreatedID.substringBeforeLast('/');
                            sObjectList[0].put('FilesBiSync_Folder_Id__c',folderCreatedID);
                            Database.update(sObjectList, false);
                        }
                    }
               
                    
                }
                 parentDW.baseUrl = sharePoint.Site_Name__c.substringBefore('/sites');
                File_Settings__c fileSettings = File_Settings__c.getInstance(Userinfo.getUserId());
                if(fileSettings.Id==null){
                    fileSettings = File_Settings__c.getInstance(Userinfo.getProfileId());
                    if(fileSettings.Id==null){
                        fileSettings = File_Settings__c.getInstance(Userinfo.getOrganizationId());
                    }
                }
                parentDW.fileSettings = fileSettings;
                parentDW.fileStorage = sharePoint;
                
            }
            
            catch (Exception e)
            {
                String errorMessage = 'Exeception: '+e.getMessage()+' <br/>Error: '+e.getStackTraceString()+' <br/>RecordId: '+recordId+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
                if(string.isNotBlank(accessError)){
                 parentDW.errorMessage=accessError;
                 errorMessage = 'Exeception: '+accessError+' <br/>Error: '+e.getStackTraceString()+' <br/>RecordId: '+recordId+' <br/>UserId: '+UserInfo.getUserId();
                }
                else{
                parentDW.errorMessage = 'Couldn\'t find files and folders';
                }
                sendErrorEmail('get details', errorMessage);
            }
        }
        return parentDW;
    }
    
    
    @AuraEnabled
    public static Map<String,Object> sharepointSearch(String queryValue){
        
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        
        File_Storage__mdt sharePoint = fileStorageList[0];
        
        
        //  String baseFolderPath=sharePoint.Site_Name__c+'Shared Documents/'+sharePoint.Root_Folder__c+'/'+'Opportunity'+'/'+'#10053 District of Mission - Municipal Hall';
        //    recordID='0063600000Dx67QAAR';
        
        String baseUri = sharePoint.Site_Name__c+'_api/search/query?querytext=';
        String targetUri=queryValue;
        String endUri='&rowlimit=10&selectproperties=';
        String finalEndUri='Title,Path,ParentLink,ParentId';
        String endPointUri = baseUri+'\''+targetUri+'\''+endUri+'\''+finalEndUri+'\''+'&EnablePhonetic=false&TrimDuplicates=false';
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('GET'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
       // req.setTimeout(20000);
        
        Http http = new Http(); 
        HTTPResponse httpResponse = new HTTPResponse();
        Map<String,Object> responseBody=new Map<String,Object>();
        
        
        try{
            httpResponse = http.send(req);  
            system.debug('body: '+httpResponse.getbody());
            if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201){
                responseBody = (Map<String,Object>)JSON.deserializeUntyped(httpResponse.getBody());
                System.debug('responseBody:: '+responseBody);
            }
            else{
                String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>SearchValue: '+queryValue+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Response Body: '+httpResponse.getBody());
                sendErrorEmail('search in SharePoint', errorMessage);
            }
        }
        catch(Exception e){
            String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>SearchValue: '+queryValue+' <br/>UserId: '+UserInfo.getUserId();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
            sendErrorEmail('search in SharePoint', errorMessage);
        } 
        return responseBody;
        
    }
    
    @AuraEnabled
    public static ParentDataWrapper getRootFolderDetails(String uri){
        
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        
        String baseUri = sharePoint.Site_Name__c+'_api/web/GetFolderById(';
        // String targetUri=uri.remove(sharePoint.Site_Name__c).replaceAll('\'','\'\'');
        String targetUri=uri.substringBeforeLast('/');
        String endUri=')?$expand=Folders/ListItemAllFields/FieldValuesAsText,Files/ListItemAllFields/FieldValuesAsText';
        String endPointUri = baseUri+'\''+targetUri+'\''+endUri;
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        
        string parentFolderName=uri.substringAfterLast('/');
        if(parentFolderName.contains('#')||parentFolderName.contains('"')||parentFolderName.contains('*')||parentFolderName.contains(':')||parentFolderName.contains('<')||parentFolderName.contains('>')||parentFolderName.contains('?')||parentFolderName.contains('/')||parentFolderName.contains('\\\\')||parentFolderName.contains('|')||parentFolderName.contains('%'))
        {
            String folderId=FilesBiSyncController.updateFolderById(targetUri,parentFolderName);
        }
        
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('GET'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        Http http = new Http(); 
        HTTPResponse httpResponse = new HTTPResponse();
        ParentDataWrapper parentDW=new ParentDataWrapper();
        try{
            httpResponse = http.send(req);  
            system.debug('body: '+httpResponse.getbody());
            if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201){
                Map<String,Object> responseBody = (Map<String,Object>)JSON.deserializeUntyped(httpResponse.getBody());
                System.debug('responseBody:: '+responseBody);
                Map<String,Object> respon1 = (Map<String,Object>)responseBody.get('d');
                Map<String,Object> filesMap = (Map<String,Object>)respon1.get('Files'); 
                List <Object> resultFile = (List <Object>)filesMap.get('results');
                Map<String,Object> foldersMap = (Map<String,Object>)respon1.get('Folders');
                List <Object> resultFolder = (List <Object>)foldersMap.get('results');
                
                List <FileDataWrapper> fileList = new List <FileDataWrapper>();
                List <FolderDataWrapper> folderList = new List <FolderDataWrapper>();
                
                parentDW.name = String.valueOf(respon1.get('Name'));
                parentDW.URI = sharePoint.Site_Name__c.substringBefore('/sites')+String.valueOf(respon1.get('ServerRelativeUrl'));
                parentDW.URI=parentDW.URI.replace(' ','%20' );      
                parentDW.serverRelativeUrl = String.valueOf(respon1.get('ServerRelativeUrl'));
                
                for(Object fi:resultFile ){
                    Map<String,Object> tempMap = (Map<String,Object>)fi;
                    FileDataWrapper fileDW = new FileDataWrapper();      
                    fileDW.name = String.valueOf(tempMap.get('Name'));
                    fileDW.fileType = fileDW.Name.substringAfterLast('.');
                    Map<String,Object> tempMap1 = (Map<String,Object>)tempMap.get('ListItemAllFields');
                    Map<String,Object> tempMap2 = (Map<String,Object>)tempMap1.get('FieldValuesAsText');
                    fileDW.author=String.valueOf(tempMap2.get('Author'));
                    fileDW.editor=String.valueOf(tempMap2.get('Editor'));
                    fileDW.URI = sharePoint.Site_Name__c.substringBefore('/sites')+String.valueOf(tempMap.get('ServerRelativeUrl'));
                    fileDW.URI=fileDW.URI.replace(' ','%20' );
                    fileDW.serverRelativeUrl = String.valueOf(tempMap.get('ServerRelativeUrl'));
                    fileDW.uniqueId = String.valueOf(tempMap.get('UniqueId'));
                    String lastModifieDTStr = String.valueOf(tempMap.get('TimeLastModified'));
                    if(lastModifieDTStr!=null){
                        lastModifieDTStr = '"'+lastModifieDTStr+'"';
                        Datetime lastModifieDT = (DateTime)JSON.deserialize(lastModifieDTStr,DateTime.class); 
                        lastModifieDTStr = lastModifieDT.format('MMM dd, yyyy hh:mm a');
                    }
                    fileDW.timeLastModified = lastModifieDTStr;
                    fileList.add(fileDW);
                }
                if(fileList.size()>0)
                {
                    parentDW.files=fileList;
                }
                for(Object fl:resultFolder ){
                    Map<String,Object> tempMap = (Map<String,Object>)fl;
                    FolderDataWrapper folderDW = new FolderDataWrapper();      
                    folderDW.name = String.valueOf(tempMap.get('Name'));
                    folderDW.fileType = 'Folder';
                    Map<String,Object> tempMap1 = (Map<String,Object>)tempMap.get('ListItemAllFields');
                    Map<String,Object> tempMap2 = (Map<String,Object>)tempMap1.get('FieldValuesAsText');
                    folderDW.author=String.valueOf(tempMap2.get('Author'));
                    folderDW.editor=String.valueOf(tempMap2.get('Editor'));
                    folderDW.URI = sharePoint.Site_Name__c.substringBefore('/sites')+String.valueOf(tempMap.get('ServerRelativeUrl'));
                    folderDW.URI=folderDW.URI.replace(' ','%20' );
                    folderDW.serverRelativeUrl = String.valueOf(tempMap.get('ServerRelativeUrl'));
                    String lastModifieDTStr = String.valueOf(tempMap.get('TimeLastModified'));
                    if(lastModifieDTStr!=null){
                        lastModifieDTStr = '"'+lastModifieDTStr+'"';
                        Datetime lastModifieDT = (DateTime)JSON.deserialize(lastModifieDTStr,DateTime.class); 
                        lastModifieDTStr = lastModifieDT.format('MMM dd, yyyy hh:mm a');
                    }
                    folderDW.timeLastModified = lastModifieDTStr;
                    folderList.add(folderDW);
                }
                if(folderList.size()>0)
                {
                    parentDW.folders=folderList;
                }
                system.debug('Parent Folder:'+parentDW);
            }else{
                String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Folder: '+uri.substringAfterLast('/')+' <br/>Path: '+uri.substringBeforeLast('/')+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+httpResponse.getBody());
                if(errorMessage.containsIgnoreCase('File Not Found')){
                    
                    errorMessage = 'Could not find the folder or it might be deleted. <br/>Folder: '+uri.substringAfterLast('/')+' <br/>Path: '+uri.substringBeforeLast('/')+' <br/>UserId: '+UserInfo.getUserId();
                }
                parentDW.errorMessage = 'Could not find the folder or it might be deleted.';
                sendErrorEmail('get root folder', errorMessage);
            }
        }catch(Exception e){
            String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Exeception: '+e.getMessage()+' <br/>UserId: '+UserInfo.getUserId();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
            parentDW.errorMessage = 'Could not find the folder or it might be deleted.';
            sendErrorEmail('get root folder', errorMessage);
        } 
        return parentDW;
        
        
    }
    
    @AuraEnabled
    public static ParentDataWrapper getSharePointFilesAndFolders(String uri){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyserverrelativeurl(';
        string targetUri=uri.remove(sharePoint.Site_Name__c);
        targetUri=urlEncoding(targetUri);
        /* // String targetUri=uri.remove(sharePoint.Site_Name__c).replaceAll('\'','\'\'');
targetUri=targetUri.replaceAll('\'','\'\'');
targetUri=targetUri.replaceAll('#', '\\%23');
// targetUri=targetUri.replaceAll('’', '%92');
targetUri=EncodingUtil.urlEncode(targetUri, 'UTF-8');
targetUri=targetUri.replaceAll('%25', '\\%23');
system.debug('test:'+targetUri);
// targetUri=targetUri.replaceAll('%27','\'\''); */
        String endUri=')?$expand=Folders/ListItemAllFields/FieldValuesAsText,Files/ListItemAllFields/FieldValuesAsText';
        String endPointUri = baseUri+'\''+targetUri+'\''+endUri;
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('GET'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        Http http = new Http(); 
        HTTPResponse httpResponse = new HTTPResponse();
        ParentDataWrapper parentDW=new ParentDataWrapper();
        try{
            httpResponse = http.send(req);  
            system.debug('body: '+httpResponse.getbody());
            if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201){
                Map<String,Object> responseBody = (Map<String,Object>)JSON.deserializeUntyped(httpResponse.getBody());
                System.debug('responseBody:: '+responseBody);
                Map<String,Object> respon1 = (Map<String,Object>)responseBody.get('d');
                Map<String,Object> filesMap = (Map<String,Object>)respon1.get('Files'); 
                List <Object> resultFile = (List <Object>)filesMap.get('results');
                Map<String,Object> foldersMap = (Map<String,Object>)respon1.get('Folders');
                List <Object> resultFolder = (List <Object>)foldersMap.get('results');
                
                List <FileDataWrapper> fileList = new List <FileDataWrapper>();
                List <FolderDataWrapper> folderList = new List <FolderDataWrapper>();
                
                parentDW.name = String.valueOf(respon1.get('Name'));
                parentDW.URI = sharePoint.Site_Name__c.substringBefore('/sites')+String.valueOf(respon1.get('ServerRelativeUrl'));
                parentDW.URI=parentDW.URI.replace(' ','%20' );      
                parentDW.serverRelativeUrl = String.valueOf(respon1.get('ServerRelativeUrl'));
                
                for(Object fi:resultFile ){
                    Map<String,Object> tempMap = (Map<String,Object>)fi;
                    FileDataWrapper fileDW = new FileDataWrapper();      
                    fileDW.name = String.valueOf(tempMap.get('Name'));
                    fileDW.fileType = fileDW.Name.substringAfterLast('.');
                    Map<String,Object> tempMap1 = (Map<String,Object>)tempMap.get('ListItemAllFields');
                    Map<String,Object> tempMap2 = (Map<String,Object>)tempMap1.get('FieldValuesAsText');
                    fileDW.author=String.valueOf(tempMap2.get('Author'));
                    fileDW.editor=String.valueOf(tempMap2.get('Editor'));
                    fileDW.URI = sharePoint.Site_Name__c.substringBefore('/sites')+String.valueOf(tempMap.get('ServerRelativeUrl'));
                    fileDW.URI=fileDW.URI.replace(' ','%20' );
                    fileDW.serverRelativeUrl = String.valueOf(tempMap.get('ServerRelativeUrl'));
                    fileDW.uniqueId = String.valueOf(tempMap.get('UniqueId'));
                    String lastModifieDTStr = String.valueOf(tempMap.get('TimeLastModified'));
                    if(lastModifieDTStr!=null){
                        lastModifieDTStr = '"'+lastModifieDTStr+'"';
                        Datetime lastModifieDT = (DateTime)JSON.deserialize(lastModifieDTStr,DateTime.class); 
                        lastModifieDTStr = lastModifieDT.format('MMM dd, yyyy hh:mm a');
                    }
                    fileDW.timeLastModified = lastModifieDTStr;
                    fileList.add(fileDW);
                }
                if(fileList.size()>0)
                {
                    parentDW.files=fileList;
                }
                for(Object fl:resultFolder ){
                    Map<String,Object> tempMap = (Map<String,Object>)fl;
                    FolderDataWrapper folderDW = new FolderDataWrapper();      
                    folderDW.name = String.valueOf(tempMap.get('Name'));
                    folderDW.fileType = 'Folder';
                    Map<String,Object> tempMap1 = (Map<String,Object>)tempMap.get('ListItemAllFields');
                    Map<String,Object> tempMap2 = (Map<String,Object>)tempMap1.get('FieldValuesAsText');
                    folderDW.author=String.valueOf(tempMap2.get('Author'));
                    folderDW.editor=String.valueOf(tempMap2.get('Editor'));
                    folderDW.URI = sharePoint.Site_Name__c.substringBefore('/sites')+String.valueOf(tempMap.get('ServerRelativeUrl'));
                    folderDW.URI=folderDW.URI.replace(' ','%20' );
                    folderDW.serverRelativeUrl = String.valueOf(tempMap.get('ServerRelativeUrl'));
                    String lastModifieDTStr = String.valueOf(tempMap.get('TimeLastModified'));
                    if(lastModifieDTStr!=null){
                        lastModifieDTStr = '"'+lastModifieDTStr+'"';
                        Datetime lastModifieDT = (DateTime)JSON.deserialize(lastModifieDTStr,DateTime.class); 
                        lastModifieDTStr = lastModifieDT.format('MMM dd, yyyy hh:mm a');
                    }
                    folderDW.timeLastModified = lastModifieDTStr;
                    folderList.add(folderDW);
                }
                if(folderList.size()>0)
                {
                    parentDW.folders=folderList;
                }
                system.debug('Parent Folder:'+parentDW);
            }else{
                uri = uri.subString(0,uri.length()-1).replaceAll('%20', ' ');
                String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Folder: '+uri.substringAfterLast('/')+' <br/>Path: '+uri.substringBeforeLast('/')+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+httpResponse.getBody());
                if(errorMessage.containsIgnoreCase('File Not Found')){
                    uri = uri.subString(0,uri.length()-1).replaceAll('%20', ' ');
                    errorMessage = 'Couldn\'t find the folder. <br/>Folder: '+uri.substringAfterLast('/')+' <br/>Path: '+uri.substringBeforeLast('/')+' <br/>UserId: '+UserInfo.getUserId();
                }
                parentDW.errorMessage = 'Couldn\'t find the folder';
                sendErrorEmail('get files and folders', errorMessage);
            }
        }catch(Exception e){
            uri = uri.subString(0,uri.length()-1).replaceAll('%20', ' ');
            String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Exeception: '+e.getMessage()+'<br/>Folder: '+uri.substringAfterLast('/')+' <br/>Path: '+uri.substringBeforeLast('/')+' <br/>UserId: '+UserInfo.getUserId();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
            parentDW.errorMessage = 'Couldn\'t find files and folders';
            sendErrorEmail('get files and folders', errorMessage);
        } 
        return parentDW;
    }
    
    
    @AuraEnabled
    public static ParentDataWrapper createFolder(String uri , String folderName){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        
        
        String targetFolderUri = uri;
        targetFolderUri = targetFolderUri.remove(sharePoint.Site_Name__c);
        String targetFolderName = folderName;
        if(targetFolderName.contains('#')||targetFolderName.contains('%'))
        {
            targetFolderName = targetFolderName.replaceAll('#', '{35}');
            targetFolderName = targetFolderName.replaceAll('%', '{37}');
        }
        String finalTargetUri = targetFolderUri+'/'+targetFolderName;
        String endPointUri = sharePoint.Site_Name__c+'_api/web/folders';
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('POST'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        jsonGen.writeFieldName('__metadata');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('type','SP.Folder');
        jsonGen.writeEndObject();
        jsonGen.writeStringField('ServerRelativeUrl',finalTargetUri);
        jsonGen.writeEndObject();
        String body = jsonGen.getAsString();
        system.debug('json'+body);
        req.setBody(body);
        
        Http http = new Http();   
        HTTPResponse httpResponse = new HTTPResponse();
        ParentDataWrapper parentDW = new ParentDataWrapper();
        try{
            httpResponse = http.send(req);
            System.debug('Code: '+httpResponse.getStatusCode()+'\nStatus: '+httpResponse.getStatus()+'\nResponse: '+httpResponse);
            if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201){
                
                
                Map<String,Object> responseBody = (Map<String,Object>)JSON.deserializeUntyped(httpResponse.getBody());
                System.debug('responseBody:: '+responseBody);
                Map<String,Object> respon1 = (Map<String,Object>)responseBody.get('d');           
                parentDW = FilesBiSyncController.getSharePointFilesAndFolders(uri);
                
                
                
            }else{
                uri=uri = uri.subString(0,uri.length()-1).replaceAll('%20', ' ');
                String errorMessage = 'New Folder Name: '+folderName+'<br/>Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+' <br/>Path: '+uri.substringBeforeLast('/')+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+httpResponse.getBody());
                //parentDW.errorMessage = 'Failed to get files and folders';
                sendErrorEmail('to create new folder', errorMessage);
            }
        }catch(Exception e){
            uri=uri = uri.subString(0,uri.length()-1).replaceAll('%20', ' ');
            String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Exeception: '+e.getMessage()+' <br/>Path: '+uri.substringBeforeLast('/')+' <br/>UserId: '+UserInfo.getUserId();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
            //parentDW.errorMessage = 'Failed to create new folder';
            sendErrorEmail('to create new folder', errorMessage);
        } 
        return parentDW;
    }
    
    @AuraEnabled
    public static ParentDataWrapper updateFolder(String uri ,String folderName){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        String targetFolderName = folderName;
        if(targetFolderName.contains('#')||targetFolderName.contains('%'))
        {
            targetFolderName = targetFolderName.replaceAll('#', '{35}');
            targetFolderName = targetFolderName.replaceAll('%', '{37}');
        }
        //targetFolderName = targetFolderName.replace(' ','%20');
        String targetUri = uri;
        targetUri = targetUri.remove(sharePoint.Site_Name__c);
        //  targetUri=targetUri.replaceAll('’', '%92'); 
        targetUri=urlEncoding(targetUri);
        String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyserverrelativeurl(';
        String endUri=')/ListItemAllFields';
        String endPointUri=baseUri+'\''+targetUri+'\''+endUri;  
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('POST'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('X-HTTP-Method', 'MERGE');
        req.setHeader('If-Match', '*');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        jsonGen.writeFieldName('__metadata');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('type','SP.Data.Shared_x0020_DocumentsItem');
        jsonGen.writeEndObject();
        jsonGen.writeStringField('Title',targetFolderName);
        jsonGen.writeStringField('FileLeafRef',targetFolderName);
        jsonGen.writeEndObject();
        String body = jsonGen.getAsString();
        req.setBody(body);
        
        Http http = new Http(); 
        HTTPResponse httpResponse = new HTTPResponse();
        ParentDataWrapper parentDW = new ParentDataWrapper();
        try{
            httpResponse = http.send(req);
            if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201 || httpResponse.getStatusCode()==204){
                System.debug('Code: '+httpResponse.getStatusCode()+'\nStatus: '+httpResponse.getStatus()+'\nResponse: '+httpResponse);
                parentDW = FilesBiSyncController.getSharePointFilesAndFolders(uri.substringBeforeLast('/'));
            }else{
                String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+' <br/>FolderName: '+folderName+' <br/>Path: '+uri+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Response Body: '+httpResponse.getBody());
                //parentDW.errorMessage = 'Failed to update folder name';
                sendErrorEmail('to update folder name', errorMessage);
            }
        }catch(Exception e){
            String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Exeception: '+e.getMessage()+' <br/>FolderName: '+folderName+' <br/>Path: '+uri+' <br/>UserId: '+UserInfo.getUserId();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
            //parentDW.errorMessage = 'Failed to update folder name';
            sendErrorEmail('to update folder name', errorMessage);
        } 
        return parentDW;
    }
    
    @AuraEnabled
    public static string updateFolderById(String Id,String folderName){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        if(folderName.contains('#')||folderName.contains('"')||folderName.contains('*')||folderName.contains(':')||folderName.contains('<')||folderName.contains('>')||folderName.contains('?')||folderName.contains('/')||folderName.contains('\\\\')||folderName.contains('|')||folderName.contains('%'))
        {
            folderName = folderName.replaceAll('#', '{35}');
            folderName = folderName.replaceAll('"', '{34}');
            folderName = folderName.replaceAll('\\*', '{42}');
            folderName = folderName.replaceAll(':', '{58}');
            folderName = folderName.replaceAll('<', '{60}');
            folderName = folderName.replaceAll('>', '{62}');
            folderName = folderName.replaceAll('\\?', '{63}');
            folderName = folderName.replaceAll('/', '{47}');
            folderName = folderName.replaceAll('\\\\', '{92}');
            folderName = folderName.replaceAll('\\|', '{124}');
            folderName = folderName.replaceAll('%', '{37}');
        }
        
        String targetFolderName = folderName;
        String targetId = Id;
        String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyid(';
        String endUri=')/ListItemAllFields';
        String endPointUri=baseUri+'\''+targetId+'\''+endUri;  
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('POST'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('X-HTTP-Method', 'MERGE');
        req.setHeader('If-Match', '*');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        jsonGen.writeFieldName('__metadata');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('type','SP.Data.Shared_x0020_DocumentsItem');
        jsonGen.writeEndObject();
        jsonGen.writeStringField('Title',targetFolderName);
        jsonGen.writeStringField('FileLeafRef',targetFolderName);
        jsonGen.writeEndObject();
        String body = jsonGen.getAsString();
        req.setBody(body);
        
        Http http = new Http(); 
        HTTPResponse httpResponse = new HTTPResponse();
        try{
            httpResponse = http.send(req);
            if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201 || httpResponse.getStatusCode()==204){
                System.debug('Code: '+httpResponse.getStatusCode()+'\nStatus: '+httpResponse.getStatus()+'\nResponse: '+httpResponse);
                
            }
            else{
                String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+' <br/>FolderId: '+targetId+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Response Body: '+httpResponse.getBody());
                sendErrorEmail('to update folder name by ID', errorMessage);
            }
        }
        catch(Exception e){
            String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Exeception: '+e.getMessage()+' <br/>FolderId: '+targetId+' <br/>UserId: '+UserInfo.getUserId();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
            //parentDW.errorMessage = 'Failed to update folder name';
            sendErrorEmail('to update folder name by ID', errorMessage);
        } 
        return targetId; 
    }
    
    @AuraEnabled
    public static String moveFolder(String sourceUri,String destUri){
        
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        
        String sfdb;
        String endPointUri=sharePoint.Site_Name__c+'_api/SP.MoveCopyUtil.MoveFolderByPath()';
        String authToken = sharePoint.SharePoint_Access_Token__c;
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('POST'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        jsonGen.writeFieldName('srcPath');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('DecodedUrl',sourceUri);
        jsonGen.writeEndObject();
        jsonGen.writeFieldName('destPath');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('DecodedUrl',destUri);
        jsonGen.writeEndObject();
        jsonGen.writeFieldName('options');
        jsonGen.writeStartObject();
        jsonGen.writeStringField('KeepBoth','false');
        jsonGen.writeStringField('ResetAuthorAndCreatedOnCopy','false');
        jsonGen.writeStringField('ShouldBypassSharedLocks','true');
        jsonGen.writeEndObject();
        jsonGen.writeEndObject();
        String body = jsonGen.getAsString();
        req.setBody(body);
        
        Http http = new Http(); 
        HTTPResponse httpResponse = new HTTPResponse();
        system.debug('jason'+body);
        
            httpResponse = http.send(req);
            if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201 || httpResponse.getStatusCode()==204){
                System.debug('Code: '+httpResponse.getStatusCode()+'\nStatus: '+httpResponse.getStatus()+'\nResponse: '+httpResponse);
                sfdb=destUri;
               
            }
            else if(httpResponse.getStatusCode()==400){
                Map<String,Object> responseBody = (Map<String,Object>)JSON.deserializeUntyped(httpResponse.getBody());
                System.debug('responseBody:: '+responseBody);
                Map<String,Object> respon1 = (Map<String,Object>)responseBody.get('error');
                Map<String,Object> message = (Map<String,Object>)respon1.get('message');
                String value=String.valueOf(message.get('value'));
                if(value == 'The destination file already exists.'){
                    sfdb=FilesBiSyncController.moveFolder(sourceUri,destUri+' (1)'); 
                    
                }
            }
            else{
                String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>Source: '+sourceUri+'<br/>Source: '+destUri+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Response Body: '+httpResponse.getBody());
                sendErrorEmail('to move folder ', errorMessage);
                sfdb='';
            }
        
        return sfdb;
    }
    
    @AuraEnabled
    public static ParentDataWrapper uploadFiles(String uri , List<String> contentVersionIds){
        Http http = new Http();
        HTTPResponse httpResponse = new HTTPResponse();
        ParentDataWrapper parentDW = new ParentDataWrapper();
        String fileName='';
        String contenType='';
        String processedFiles='';
        String contentDocumentId='';
        try{
            List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                       From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
            File_Storage__mdt sharePoint = fileStorageList[0];
            List<ContentVersion> cvList = [select id, title, ContentDocumentId, FileExtension, versionData from ContentVersion where Id in :contentVersionIds order by createddate];
            List<Id> contentDocIdList = new List<Id>();
            for(ContentVersion each : cvList){
                contentDocumentId=each.ContentDocumentId;
                Blob body=each.versionData;
                fileName = each.Title+'.'+each.FileExtension;
                fileName = fileName.replace(' ','%20');
                /*   fileName = fileName.replaceAll('\'','\'\'');
				fileName=fileName.replaceAll('’', '%92'); */
                fileName=urlEncoding(fileName);
                String targetFolderName='\''+fileName+'\'';
                String targetUri = uri;
                targetUri = targetUri.remove(sharePoint.Site_Name__c);
                targetUri=urlEncoding(targetUri);
                //      targetUri=targetUri.replaceAll('’', '%92');
                String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyserverrelativeurl(';
                String endUri=')/Files/add(url='+targetFolderName+',overwrite=true)';
                String endPointUri=baseUri+'\''+targetUri+'\''+endUri;  
                String attachment=EncodingUtil.base64Encode(body);
                contenType=each.FileExtension;
                String authToken = sharePoint.SharePoint_Access_Token__c;
                
                HttpRequest req = new HttpRequest(); 
                req.setHeader('Authorization','Bearer '+ authToken);
                req.setEndpoint(endPointUri);        
                req.setMethod('POST'); 
                req.setHeader('Connection', 'keep-alive');
                req.setHeader('Accept', 'application/json;odata=verbose');
                req.setHeader('Content-Type', contenType);
                req.setHeader('Content-Length', String.valueof(attachment.length()));
                Blob fileBlob=EncodingUtil.base64Decode(attachment);
                req.setBodyAsBlob(fileBlob);
                
                processedFiles=processedFiles+', '+fileName+'('+contenType+')';
                httpResponse = http.send(req);
                if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201){
                    System.debug('res' + httpResponse.getBody());
                }else{
                    String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>File Name: '+processedFiles+'<br/>Record: '+contentDocumentId+'<br/>User: '+UserInfo.getUserId();
                    System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+httpResponse.getBody());
                    //parentDW.errorMessage = 'Failed to upload the file';
                    sendErrorEmail('upload the file:'+processedFiles, errorMessage);
                }
                contentDocIdList.add(each.ContentDocumentId);
            }
            parentDW = FilesBiSyncController.getSharePointFilesAndFolders(uri);
            Database.delete(contentDocIdList, false);
            Database.emptyRecycleBin(contentDocIdList);
        }catch(Exception e){
            String errorMessage = 'Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+'<br/>File Name: '+processedFiles+'<br/>Record: '+contentDocumentId+'<br/>User: '+UserInfo.getUserId()+'<br/>Exeception: '+e.getMessage();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception: '+e.getMessage()+' \nErrorMessage: '+errorMessage);
            //parentDW.errorMessage = 'Failed to upload the file';
            sendErrorEmail('upload the file:'+processedFiles, errorMessage);
        }
        return parentDW;
    }
    
    @AuraEnabled
    public static ParentDataWrapper massDeleteFileAndFolder(List<String> folderUrlList,List<String>fileUrlList){
        
        ParentDataWrapper parentDW=new ParentDataWrapper();
        
        if(folderUrlList.size()>0){
        for(String ur:folderUrlList){
            
            parentDW=FilesBiSyncController.deleteFolder(ur);
        }
        }
        if(fileUrlList.size()>0){
        for(String ur:fileUrlList){
            parentDW=FilesBiSyncController.deleteFile(ur);
            
        }
        }
        return parentDW;
        
     }
    
    @AuraEnabled
    public static ParentDataWrapper deleteFolder(String uri){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        String targetFolderUri = uri;
        targetFolderUri = targetFolderUri.remove(sharePoint.Site_Name__c);
        targetFolderUri=urlEncoding(targetFolderUri);
        // targetFolderUri=targetFolderUri.replaceAll('’', '%92');
        String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyserverrelativeurl(';
        String targetUri = targetFolderUri;
        String endUri = ')/recycle';
        String endPointUri = baseUri+'\''+targetUri+'\''+endUri;   
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('DELETE'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        Http http = new Http();        
        HTTPResponse res = http.send(req);
        if(res.getStatusCode()==200){
        System.debug('Code: '+res.getStatusCode()+'\nStatus: '+res.getStatus()+'\nResponse: '+res);
        }
        else
        {
            
                String errorMessage = 'Folder Name: '+uri.substringAfterLast('/')+'<br/>Status: '+res.getStatus()+'<br/>Status Code: '+res.getStatuscode()+'<br/>Message: '+res.getBody()+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+res.getBody());
                
                sendErrorEmail('delete folder method failed', errorMessage);
                    
        }
        ParentDataWrapper parentDW=FilesBiSyncController.getSharePointFilesAndFolders(uri.substringBeforeLast('/'));
        return parentDW;
    }
    
   /* @AuraEnabled
    public static ParentDataWrapper deleteFolders(list<String> uriList){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
         Http http = new Http();
        for(String uri : uriList){
        String targetFolderUri = uri;
        targetFolderUri = targetFolderUri.remove(sharePoint.Site_Name__c);
        targetFolderUri=urlEncoding(targetFolderUri);
        // targetFolderUri=targetFolderUri.replaceAll('’', '%92');
        String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyserverrelativeurl(';
        String targetUri = targetFolderUri;
        String endUri = ')/recycle';
        String endPointUri = baseUri+'\''+targetUri+'\''+endUri;   
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('DELETE'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
               
        HTTPResponse res = http.send(req);
        if(res.getStatusCode()==200){
        System.debug('Code: '+res.getStatusCode()+'\nStatus: '+res.getStatus()+'\nResponse: '+res);
        }
        else
        {
            
                String errorMessage = 'Folder Name: '+uri.substringAfterLast('/')+'<br/>Status: '+res.getStatus()+'<br/>Status Code: '+res.getStatuscode()+'<br/>Message: '+res.getBody()+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+res.getBody());
                
                sendErrorEmail('delete folder method failed', errorMessage);
                    
        }
        }
        ParentDataWrapper parentDW=FilesBiSyncController.getSharePointFilesAndFolders(uriList[0].substringBeforeLast('/'));
        return parentDW;
    }*/
    
    
    @AuraEnabled
    public static ParentDataWrapper deleteFile(String uri ){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        String targetFileDeleteName = uri.substringAfterLast('/');
        targetFileDeleteName=urlEncoding(targetFileDeleteName);
        //   targetFileDeleteName=targetFileDeleteName.replaceAll('’', '%92');
        String targetFileUri = uri.substringBeforeLast('/');
        targetFileUri = targetFileUri.remove(sharePoint.Site_Name__c);
        targetFileUri=urlEncoding(targetFileUri);
        // targetFileUri=targetFileUri.replaceAll('’', '%92');
        String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyserverrelativeurl(';
        String targetUri = targetFileUri;
        String endUri = ')/Files('+'\''+targetFileDeleteName+'\''+')/recycle';
        String endPointUri = baseUri+'\''+targetUri+'\''+endUri;
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('DELETE'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        Http http = new Http();        
        HTTPResponse res = http.send(req);
        if(res.getStatusCode()==200){
        System.debug('Code: '+res.getStatusCode()+'\nStatus: '+res.getStatus()+'\nResponse: '+res);
        }
        else
        {
            
                String errorMessage = 'File Name: '+uri.substringAfterLast('/')+'<br/>Status: '+res.getStatus()+'<br/>Status Code: '+res.getStatuscode()+'<br/>Message: '+res.getBody()+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+res.getBody());
                
                sendErrorEmail('delete file method failed', errorMessage);
                    
        }
        ParentDataWrapper parentDW=FilesBiSyncController.getSharePointFilesAndFolders(uri.substringBeforeLast('/'));
        return parentDW;
    }
    
   /* @AuraEnabled
    public static ParentDataWrapper deleteFiles(list<String> uriList ){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        Http http = new Http();
        for(String uri : uriList){
        String targetFileDeleteName = uri.substringAfterLast('/');
        targetFileDeleteName=urlEncoding(targetFileDeleteName);
        //   targetFileDeleteName=targetFileDeleteName.replaceAll('’', '%92');
        String targetFileUri = uri.substringBeforeLast('/');
        targetFileUri = targetFileUri.remove(sharePoint.Site_Name__c);
        targetFileUri=urlEncoding(targetFileUri);
        // targetFileUri=targetFileUri.replaceAll('’', '%92');
        String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyserverrelativeurl(';
        String targetUri = targetFileUri;
        String endUri = ')/Files('+'\''+targetFileDeleteName+'\''+')/recycle';
        String endPointUri = baseUri+'\''+targetUri+'\''+endUri;
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('DELETE'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        
        HTTPResponse res = http.send(req);
        if(res.getStatusCode()==200){
        System.debug('Code: '+res.getStatusCode()+'\nStatus: '+res.getStatus()+'\nResponse: '+res);
        }
        else
        {
            
                String errorMessage = 'File Name: '+uri.substringAfterLast('/')+'<br/>Status: '+res.getStatus()+'<br/>Status Code: '+res.getStatuscode()+'<br/>Message: '+res.getBody()+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+res.getBody());
                
                sendErrorEmail('delete file method failed', errorMessage);
                    
        }
        }
        ParentDataWrapper parentDW=FilesBiSyncController.getSharePointFilesAndFolders(uriList[0].substringBeforeLast('/'));
        return parentDW;
    }
   */
    
    @AuraEnabled
    public static PublicUrlWrapper getSharePointFilePublicURL(List<String> listURI){
        system.debug('listURI::'+listURI);
       
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
       PublicUrlWrapper urlWrp=new PublicUrlWrapper();
       Map<String,String> publicUrl= new Map<String,String>();
        
        
         Http http = new Http();
        if(listURI.size()>0){
        for(String url : listURI){
        String targetUrl=url;
        String baseUri = sharePoint.Site_Name__c+'_api/SP.Web.CreateAnonymousLink';
        String endPointUri = baseUri;
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest();        
        req.setEndpoint(endPointUri);        
        req.setMethod('POST'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', 'application/json;odata=verbose');
        req.setHeader('Authorization','Bearer '+ authToken);
        
        JSONGenerator jsonGen = JSON.createGenerator(true);
        jsonGen.writeStartObject();
        jsonGen.writeStringField('url',url);
        jsonGen.writeStringField('isEditLink','false');
        jsonGen.writeEndObject();
        String body = jsonGen.getAsString();
        system.debug('json'+body);
        req.setBody(body);
        
        
        HTTPResponse res = http.send(req);
        if(res.getStatusCode()==200){
        System.debug('Code: '+res.getStatusCode()+'\nStatus: '+res.getStatus()+'\nResponse: '+res);
           Map<String,Object> responseBody = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                System.debug('responseBody:: '+responseBody);
                Map<String,Object> respon1 = (Map<String,Object>)responseBody.get('d');
            System.debug('responseBody:: '+respon1);
            string publicSharingUrl =String.valueOf(respon1.get('CreateAnonymousLink'));
            publicUrl.put(url,publicSharingUrl);
        }
        else
        {
            
                String errorMessage = 'Shared File Path: '+url+'<br/>Status: '+res.getStatus()+'<br/>Status Code: '+res.getStatuscode()+'<br/>Message: '+res.getBody()+' <br/>UserId: '+UserInfo.getUserId();
                System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+res.getBody());
                Map<String,Object> responseBody = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                System.debug('responseBody:: '+responseBody);
                Map<String,Object> respon1 = (Map<String,Object>)responseBody.get('error');
            Map<String,Object> respon2 = (Map<String,Object>)respon1.get('message');
           string message =String.valueOf(respon2.get('value'));
            System.debug('message:: '+message);
                sendErrorEmail('getSharePointFilePublicURL method failed', errorMessage);
                    
        }
        }
        }
        if(publicUrl.size()>0)
        {
            urlWrp.urlMap=publicUrl;
        }
        
        return urlWrp;
        
    }
    
    @AuraEnabled
    public static TemplateDataWrapper getTemplateDetails(Id recordId){
        String objectName = String.escapeSingleQuotes(recordId.getSObjectType().getDescribe().getName());
        String sObjectQuery = 'SELECT Id,Name FROM '+objectName+' WHERE Id IN (\'' + recordId + '\')';
        List<SObject> sObjectList = Database.query(sObjectQuery);
        
        List<Template_Structure__mdt> templateStructureMtdList = [SELECT Id,MasterLabel,DeveloperName,Folder_Name__c,Object_Name__c
                                                                  From Template_Structure__mdt Where Object_Name__c =: objectName order by Order_of_Folders__c];
        List<String> folderList = new List<String>();
        for(Template_Structure__mdt each : templateStructureMtdList){
            if(each.Folder_Name__c!=null)
                folderList.add(each.Folder_Name__c);
        }
        TemplateDataWrapper templateDW = new TemplateDataWrapper();
        templateDW.objName = objectName;
        templateDW.folderList = folderList;
        templateDW.foldersAvailable = folderList.size()>0;
        return templateDW;
    }
    
    @AuraEnabled
    public static ParentDataWrapper createTemplate(String uri, Id recordId)
    {
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        String objectName = String.escapeSingleQuotes(recordId.getSObjectType().getDescribe().getName());
        String sObjectQuery = 'SELECT Id,Name FROM '+objectName+' WHERE Id IN (\'' + recordId + '\')';
        List<SObject> sObjectList = Database.query(sObjectQuery);
        
        List<Template_Structure__mdt> templateStructureMtdList = [SELECT Id,MasterLabel,DeveloperName,Folder_Name__c,Object_Name__c
                                                                  From Template_Structure__mdt Where Object_Name__c =: objectName];
        String targetFolderUri = uri;
        targetFolderUri = targetFolderUri.remove(sharePoint.Site_Name__c);
        String finalTargetUri = targetFolderUri;
        String endPointUri = sharePoint.Site_Name__c+'_api/web/folders';
        String authToken = sharePoint.SharePoint_Access_Token__c;
        if(templateStructureMtdList.size()>0){
            for(Template_Structure__mdt tem:templateStructureMtdList){     
                HttpRequest req = new HttpRequest();        
                req.setEndpoint(endPointUri);        
                req.setMethod('POST'); 
                req.setHeader('Connection', 'keep-alive');
                req.setHeader('Accept', 'application/json;odata=verbose');
                req.setHeader('Content-Type', 'application/json;odata=verbose');
                req.setHeader('Authorization','Bearer '+ authToken);
                finalTargetUri=targetFolderUri;     
                finalTargetUri=finalTargetUri+'/'+tem.Folder_Name__c;
                finalTargetUri=finalTargetUri.replace(' ','%20');
                
                JSONGenerator jsonGen = JSON.createGenerator(true);
                jsonGen.writeStartObject();
                jsonGen.writeFieldName('__metadata');
                jsonGen.writeStartObject();
                jsonGen.writeStringField('type','SP.Folder');
                jsonGen.writeEndObject();
                jsonGen.writeStringField('ServerRelativeUrl',finalTargetUri);
                jsonGen.writeEndObject();
                String body = jsonGen.getAsString();
                system.debug('json'+body);
                req.setBody(body);
                
                Http http = new Http();        
                HTTPResponse res = http.send(req);
                System.debug('Code: '+res.getStatusCode()+'\nStatus: '+res.getStatus()+'\nResponse: '+res);
            }
        }
        ParentDataWrapper parentDW = FilesBiSyncController.getSharePointFilesAndFolders(uri);
        return parentDW;
    }
    
    public class moveFolderFromtrigger implements Queueable,Database.AllowsCallouts {
        private ID recordId;
        private String fileBisyncId;
        public moveFolderFromtrigger(ID recordId,String fileBisyncId) {
            this.recordId = recordId;
            this.fileBisyncId= fileBisyncId;
        } 
        
        public void execute(QueueableContext context) {
            String objectName = String.escapeSingleQuotes(recordId.getSObjectType().getDescribe().getName());
            String sObjectQuery = 'SELECT Id,Name,FilesBiSync_Folder_Id__c FROM '+objectName+' WHERE Id IN (\'' + recordId + '\')';
            List<SObject> sObjectList = Database.query(sObjectQuery);
            
            List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                       From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
            File_Storage__mdt sharePoint = fileStorageList[0];
            
            
            ParentDataWrapper parentDW = FilesBiSyncController.getRootFolderDetails(fileBisyncId);
            String source=parentDW.URI.replace('%20',' ' );
            
      /*      String oppFileBisyncId=String.valueOf(sObjectList[0].get('FilesBiSync_Folder_Id__c'))+'/'+String.valueOf(sObjectList[0].get('Name'));
            ParentDataWrapper parentDW1 = FilesBiSyncController.getRootFolderDetails(oppFileBisyncId); */
            
            
            
            String folderName=String.valueOf(sObjectList[0].get('Name'));
            if(folderName.contains('#')||folderName.contains('"')||folderName.contains('*')||folderName.contains(':')||folderName.contains('<')||folderName.contains('>')||folderName.contains('?')||folderName.contains('/')||folderName.contains('\\\\')||folderName.contains('|')||folderName.contains('%'))
            {
                folderName = folderName.replaceAll('#', '{35}');
                folderName = folderName.replaceAll('"', '{34}');
                folderName = folderName.replaceAll('\\*', '{42}');
                folderName = folderName.replaceAll(':', '{58}');
                folderName = folderName.replaceAll('<', '{60}');
                folderName = folderName.replaceAll('>', '{62}');
                folderName = folderName.replaceAll('\\?', '{63}');
                folderName = folderName.replaceAll('/', '{47}');
                folderName = folderName.replaceAll('\\\\', '{92}');
                folderName = folderName.replaceAll('\\|', '{124}');
                folderName = folderName.replaceAll('%', '{37}');
            }
          
String destUri = sharePoint.Site_Name__c+'Shared Documents/'+sharePoint.Root_Folder__c+'/'+objectName+'/'+folderName; 
       //    String destUri=parentDW1.URI.replace('%20',' ' )+'/'+folderName;
           String sfdbFile = FilesBiSyncController.moveFolder(source, destUri);
            
            if(String.isNotBlank(sfdbFile)){
                String fileName = '.'+recordId+'.sfdb';
            String fileUri=sfdbFile.remove(sharePoint.Site_Name__c);
             fileUri=fileUri.replaceall(' ','%20');
            FilesBiSyncController.createFile(fileUri,fileName);
            }
            
            /*  sObjectList[0].put('FilesBiSync_Folder_Id__c',fileBisyncId.substringBefore('/'));
Database.update(sObjectList, false); */
            
        }
    }
  
    
    @future(callout=true)
    public static void createDefaultFoldersFromTrigger(Id recordId){
        
        String objectName = String.escapeSingleQuotes(recordId.getSObjectType().getDescribe().getName());
        String sObjectQuery = 'SELECT Id,Name,FilesBiSync_Folder_Id__c FROM '+objectName+' WHERE Id IN (\'' + recordId + '\')' ;
         List<SObject> sObjectList = Database.query(sObjectQuery);
        
      
        String folderId=FilesBiSyncController.createDefaultFolders(recordId );
        sObjectList[0].put('FilesBiSync_Folder_Id__c',folderId.substringBefore('/'));
       
        Database.update(sObjectList, false);
      
        
        
    }
    
    public static String createDefaultFolders(ID recordId ){
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        String objectName = String.escapeSingleQuotes(recordId.getSObjectType().getDescribe().getName());
        String sObjectQuery = 'SELECT Id,Name,FilesBiSync_Folder_Id__c FROM '+objectName+' WHERE Id IN (\'' + recordId + '\')';
        List<SObject> sObjectList = Database.query(sObjectQuery);
        
        String folderName=string.valueOf(sObjectList[0].get('Name'));
        if(folderName.contains('#')||folderName.contains('"')||folderName.contains('*')||folderName.contains(':')||folderName.contains('<')||folderName.contains('>')||folderName.contains('?')||folderName.contains('/')||folderName.contains('\\\\')||folderName.contains('|')||folderName.contains('%'))
        {
            folderName = folderName.replaceAll('#', '{35}');
            folderName = folderName.replaceAll('"', '{34}');
            folderName = folderName.replaceAll('\\*', '{42}');
            folderName = folderName.replaceAll(':', '{58}');
            folderName = folderName.replaceAll('<', '{60}');
            folderName = folderName.replaceAll('>', '{62}');
            folderName = folderName.replaceAll('\\?', '{63}');
            folderName = folderName.replaceAll('/', '{47}');
            folderName = folderName.replaceAll('\\\\', '{92}');
            folderName = folderName.replaceAll('\\|', '{124}');
            folderName = folderName.replaceAll('%', '{37}');
        }
        system.debug('FOlder Name'+folderName);
        
        List<Template_Structure__mdt> templateStructureMtdList = [SELECT Id,MasterLabel,DeveloperName,Folder_Name__c,Object_Name__c
                                                                  From Template_Structure__mdt Where Object_Name__c =: objectName];
        
        String targetUri = 'Shared Documents/'+sharePoint.Root_Folder__c+'/'+objectName;
        targetUri=targetUri.replace(' ', '%20');  
        String folderCreatedID = ' ';
        //   ParentDataWrapper parentDW = FilesBiSyncController.createFolder(targetUri, ''+sObjectList[0].get('Name'));
        Boolean defaultFolder=True;
        String targetRootFolderUri = targetUri;
        targetRootFolderUri = targetRootFolderUri.remove(sharePoint.Site_Name__c);
        String targertRootFolderName =folderName;
        String finalRootTargetUri = targetRootFolderUri+'/'+targertRootFolderName;
        String endRootPointUri = sharePoint.Site_Name__c+'_api/web/folders';
        String authTokenRoot = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req1 = new HttpRequest();        
        req1.setEndpoint(endRootPointUri);        
        req1.setMethod('POST'); 
        req1.setHeader('Connection', 'keep-alive');
        req1.setHeader('Accept', 'application/json;odata=verbose');
        req1.setHeader('Content-Type', 'application/json;odata=verbose');
        req1.setHeader('Authorization','Bearer '+ authTokenRoot);
        
        JSONGenerator jsonGen1 = JSON.createGenerator(true);
        jsonGen1.writeStartObject();
        jsonGen1.writeFieldName('__metadata');
        jsonGen1.writeStartObject();
        jsonGen1.writeStringField('type','SP.Folder');
        jsonGen1.writeEndObject();
        jsonGen1.writeStringField('ServerRelativeUrl',finalRootTargetUri);
        jsonGen1.writeEndObject();
        String body1 = jsonGen1.getAsString();
        system.debug('json'+body1);
        req1.setBody(body1);
        
        Http http1 = new Http();   
        HTTPResponse httpResponse1 = new HTTPResponse();
        httpResponse1 = http1.send(req1);
        System.debug('Code: '+httpResponse1.getStatusCode()+'\nStatus: '+httpResponse1.getStatus()+'\nResponse: '+httpResponse1);
        if(httpResponse1.getStatusCode()==200 || httpResponse1.getStatusCode()==201){
            
            
            Map<String,Object> responseBody1 = (Map<String,Object>)JSON.deserializeUntyped(httpResponse1.getBody());
            System.debug('responseBody1:: '+responseBody1);
            Map<String,Object> respon2 = (Map<String,Object>)responseBody1.get('d');
            folderCreatedID=String.valueOf(respon2.get('UniqueId'));
            
            folderCreatedID=folderCreatedID+'/'+targertRootFolderName;
            ParentDataWrapper parentDW = FilesBiSyncController.getRootFolderDetails(folderCreatedID);
            
            if(parentDW.folders!=null){
                defaultFolder=false;
            }
            String fileName = '.'+recordId+'.sfdb';
            String fileUri=parentDW.URI.remove(sharePoint.Site_Name__c);
            FilesBiSyncController.createFile(fileUri,fileName);
            
            folderCreatedID=String.valueOf(respon2.get('UniqueId'))+'/'+folderName;
            
        }else{
            defaultFolder=false;
            String errorMessage = 'New Folder Name: '+string.valueOf(sObjectList[0].get('Name'))+'<br/>Status: '+httpResponse1.getStatus()+'<br/>Status Code: '+httpResponse1.getStatuscode()+'<br/>Message: '+httpResponse1.getBody()+' <br/>UserId: '+UserInfo.getUserId();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+httpResponse1.getBody());
            //parentDW.errorMessage = 'Failed to get files and folders';
            sendErrorEmail('create new root folder', errorMessage);
        }
        
        
        //  
        if(defaultFolder==true){
            targetUri = 'Shared Documents/'+sharePoint.Root_Folder__c+'/'+objectName+'/'+folderName;
            String finaltargetUri = targetUri;
            String endPointUri = sharePoint.Site_Name__c+'_api/web/folders';
            String authToken = sharePoint.SharePoint_Access_Token__c;
            
            if(templateStructureMtdList.size()>0){
                for(Template_Structure__mdt tem:templateStructureMtdList){     
                    HttpRequest req = new HttpRequest();        
                    req.setEndpoint(endPointUri);        
                    req.setMethod('POST'); 
                    req.setHeader('Connection', 'keep-alive');
                    req.setHeader('Accept', 'application/json;odata=verbose');
                    req.setHeader('Content-Type', 'application/json;odata=verbose');
                    req.setHeader('Authorization','Bearer '+ authToken);
                    finaltargetUri = targetUri;
                    finaltargetUri = finaltargetUri+'/'+tem.Folder_Name__c;
                    finaltargetUri = finaltargetUri.replace(' ','%20');
                    
                    JSONGenerator jsonGen = JSON.createGenerator(true);
                    jsonGen.writeStartObject();
                    jsonGen.writeFieldName('__metadata');
                    jsonGen.writeStartObject();
                    jsonGen.writeStringField('type','SP.Folder');
                    jsonGen.writeEndObject();
                    jsonGen.writeStringField('ServerRelativeUrl',finaltargetUri);
                    jsonGen.writeEndObject();
                    String body = jsonGen.getAsString();
                    system.debug('json'+body);
                    req.setBody(body);
                    
                    Http http = new Http();        
                    HTTPResponse httpResponse = http.send(req);
                    if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201){
                        System.debug('Code: '+httpResponse.getStatusCode()+'\nStatus: '+httpResponse.getStatus()+'\nResponse: '+httpResponse);
                        
                    }else{
                        String errorMessage = 'New Folder Name: '+tem.Folder_Name__c+'<br/>Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+' <br/>UserId: '+UserInfo.getUserId();
                        System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+httpResponse.getBody());
                        //parentDW.errorMessage = 'Failed to upload the file';
                        sendErrorEmail('create default folders', errorMessage);
                    }
                }
            }
            
        } 
        return folderCreatedID;
    }
    
    @AuraEnabled
    public static void createFile(String Uri,String Name){
        
        List<File_Storage__mdt> fileStorageList = [SELECT Id,MasterLabel,DeveloperName,Name__c,Object_s__c,Type__c,Client_ID__c,Client_Secret__c,Resource_ID__c,Tenant_ID__c,SharePoint_Access_Token__c,Site_Name__c,Root_Folder__c
                                                   From File_Storage__mdt Where Type__c= 'SharePointOnline' limit 1];
        File_Storage__mdt sharePoint = fileStorageList[0];
        Http http = new Http();
        HTTPResponse httpResponse = new HTTPResponse();
        String fileName='';
        String contenType='';
        String processedFiles='';
        String fileUri=Uri;
        Blob body=blob.valueOf(Name);
        fileName = Name;
        
        fileName=urlEncoding(fileName);
        String targetFolderName='\''+fileName+'\'';
        String targetFileUri = fileUri;
        targetFileUri = targetFileUri.remove(sharePoint.Site_Name__c);
        targetFileUri=urlEncoding(targetFileUri);
        String baseUri = sharePoint.Site_Name__c+'_api/web/getfolderbyserverrelativeurl(';
        String endUri=')/Files/add(url='+targetFolderName+',overwrite=true)';
        String endPointUri=baseUri+'\''+targetFileUri+'\''+endUri;  
        String attachment=EncodingUtil.base64Encode(body);
        contenType='.sfdb';
        String authToken = sharePoint.SharePoint_Access_Token__c;
        
        HttpRequest req = new HttpRequest(); 
        req.setHeader('Authorization','Bearer '+ authToken);
        req.setEndpoint(endPointUri);        
        req.setMethod('POST'); 
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Accept', 'application/json;odata=verbose');
        req.setHeader('Content-Type', contenType);
        req.setHeader('Content-Length', String.valueof(attachment.length()));
        Blob fileBlob=EncodingUtil.base64Decode(attachment);
        req.setBodyAsBlob(fileBlob);
        
        processedFiles=processedFiles+', '+fileName+'('+contenType+')';
        httpResponse = http.send(req);
        if(httpResponse.getStatusCode()==200 || httpResponse.getStatusCode()==201){
            System.debug('res' + httpResponse.getBody());
        }
        else{
            String errorMessage = 'New File Name: '+fileName+'<br/>Status: '+httpResponse.getStatus()+'<br/>Status Code: '+httpResponse.getStatuscode()+'<br/>Message: '+httpResponse.getBody()+' <br/>UserId: '+UserInfo.getUserId();
            System.debug(System.LoggingLevel.DEBUG, 'Exeception Executed: '+httpResponse.getBody());
            //parentDW.errorMessage = 'Failed to upload the file';
            sendErrorEmail('create Default File', errorMessage);
        }
        
        
        
    }
    
    @AuraEnabled
    public static void sendErrorEmail(String subjectReason, String exceptionMessage){   //String subject, String reason 
        File_Settings__c fileSettings = File_Settings__c.getInstance(Userinfo.getOrganizationId());
        if(fileSettings.Admin_Mail_Address__c==null)
            return;
        List<EmailTemplate> template = [SELECT DeveloperName, Id, Subject, HtmlValue, Body FROM EmailTemplate Where DeveloperName = 'FilesBiSync_Error_Template'];
        String templateSubject = template[0].Subject;
        templateSubject = templateSubject.replace('{reason}', subjectReason);
        String body = template[0].HtmlValue;
        body = body.replace('{exceptionMessage}', exceptionMessage);
        
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        List<String>  sendTo= New List<String>();
        List<String> emailIdsLst = fileSettings.Admin_Mail_Address__c.split(',');
        for(string each:emailIdsLst){
            sendTo.add(each);
        }
        email.setToAddresses(sendTo);
        email.setSubject(templateSubject);
        email.setHtmlBody(body);
        emailList.add(email);
        if(emailList.size()>0){
            system.debug(emailList);
            Messaging.sendEmail(emailList);
        }
    }
    
    public static String urlEncoding(String Url){
        String encodedUrl=Url;
        encodedUrl=Url.replaceAll('\'','\'\'');
        encodedUrl=EncodingUtil.urlEncode(encodedUrl, 'UTF-8');
        return encodedUrl;
    }
    public static String getDomainName(String url) {
    String patterne = 'https?://([\\w.-]+)';
    Pattern p = Pattern.compile(patterne);
    Matcher m = p.matcher(url);
    if (m.find()) {
        return m.group(1);
    } else {
        return null;
    }
}
    
    @AuraEnabled(cacheable=true)
    public static List<EmailTemplate> getEmailTemplateDetails(){
        
        String folder = System.Label.External_File_Share_Template_Folder;
        List<EmailTemplate> emailTemplates = new List<EmailTemplate>();
        if(!String.isBlank(folder)){
            emailTemplates = [select Id, Name, Subject, HtmlValue, DeveloperName, FolderName from EmailTemplate where isActive = true and Folder.Name =: folder ];  
        }
        
   
        if(emailTemplates != null){
            return emailTemplates;
        }
        return null;
        
    }
    @AuraEnabled
    public static String sendEmail( String emailSubject, String emailContent, List<String> toRecipients, List<String> ccRecipients){
        String status = '';
        try{
            if(toRecipients.isEmpty()){
                status = 'Recipients cannot be empty';
                return status;
            }
                List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setSubject(emailSubject);
                email.setHtmlBody(emailContent);
                email.setToAddresses(toRecipients);
                if(ccRecipients!=null)
                    email.setCcAddresses(ccRecipients);
                emailList.add(email);
                if(!Test.isRunningTest() && emailList.size()>0){
                    Messaging.sendEmail(emailList);
                    status = '';
                   
                }
             return status;
            
        }
        catch(exception e){
            String errorMessage = 'Exeception: '+e.getMessage()+'<br/>Line: '+e.getLineNumber()+'<br/>Type: '+e.getTypeName();
            sendErrorEmail('Failed to send mail', errorMessage);
            status = 'Failed to send mail'; 
            return status;
        }
    }
    
    public class ParentDataWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public List<FileDataWrapper> files;
        @AuraEnabled public List<FolderDataWrapper> folders;
        @AuraEnabled public String baseUrl;
        @AuraEnabled public String URI;
        @AuraEnabled public String serverRelativeUrl;
        @AuraEnabled public String timeLastModified;
        @AuraEnabled public File_Settings__c fileSettings;
        @AuraEnabled public File_Storage__mdt fileStorage;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String folderUniqueId;
    }
    
    public class FileDataWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String fileType;
        @AuraEnabled public String author;
        @AuraEnabled public String editor;
        @AuraEnabled public String URI;
        @AuraEnabled public String serverRelativeUrl;
        @AuraEnabled public String timeLastModified;
        @AuraEnabled public String uniqueId; 
    }
    
    public class FolderDataWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String fileType;
        @AuraEnabled public String author;
        @AuraEnabled public String editor;
        @AuraEnabled public String URI;
        @AuraEnabled public String serverRelativeUrl;
        @AuraEnabled public String timeLastModified; 
    }
    
    public class TemplateDataWrapper {
        @AuraEnabled public String objName;
        @AuraEnabled public List<String> folderList;
        @AuraEnabled public Boolean foldersAvailable;
        @AuraEnabled public String currentFolderName;
    }
    public class PublicUrlWrapper {
        @AuraEnabled public Map<String, String> urlMap;
        
    }
     
}