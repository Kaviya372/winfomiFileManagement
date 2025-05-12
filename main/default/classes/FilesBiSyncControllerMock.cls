@isTest
global class FilesBiSyncControllerMock implements HttpCalloutMock {
    
    // Implement this interface method
    global HTTPResponse respond(HTTPRequest req) {
        String endPoint = req.getEndpoint();
        
        String body = '';
        if(endPoint.contains('/tokens/OAuth/2/')){
            body = '{"access_token":"Test","refresh_token":"Test"}';
        } else if(endPoint.contains('?$expand=Folders/ListItemAllFields/FieldValuesAsText,Files/ListItemAllFields/FieldValuesAsText')){
            
            body = '{"d":{"Files":{"results":[{"Name":"test","ServerRelativeUrl":"test","ListItemAllFields" : {"FieldValuesAsText": {"Author": "Jon Green","Editor": "Jon Green"}}}]},"Folders":{"results":[{"Name":"test","ServerRelativeUrl":"test","ListItemAllFields": {"FieldValuesAsText": {"Author": "Jon Green","Editor": "Jon Green"}}}]},"Name": "Zip Folder"}}';
            
        }
        else if(endPoint.contains('_api/web/folders')){
            
            body = '{"d":{"Files":{"results":[{"Name":"test","ServerRelativeUrl":"test"}]},"Folders":{"results":[{"Name":"test","ServerRelativeUrl":"test"}]},"Name": "Zip Folder","UniqueId": "ae13a6d3-f990-4cd6-85c3-83298c49be1d"}}';
        }
        else if(endPoint.contains('/recycle')){
            body= '{"d":{"Recycle" : "554c8c13-7c98-48de-ae65-88b2a59b96a4"}}';
        }
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setStatus('OK');
        res.setBody(body);
        return res;
    }
}