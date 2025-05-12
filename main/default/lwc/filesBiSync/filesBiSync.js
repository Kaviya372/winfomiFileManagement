import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';
import FileBiSyncImages from '@salesforce/resourceUrl/FilesBiSyncImages';
import getDetails from '@salesforce/apex/FilesBiSyncController.getDetails';
import getFilesAndFolders from '@salesforce/apex/FilesBiSyncController.getSharePointFilesAndFolders';
import uploadFiles from '@salesforce/apex/FilesBiSyncController.uploadFiles';
import createFolder from '@salesforce/apex/FilesBiSyncController.createFolder';
import createTemplate from '@salesforce/apex/FilesBiSyncController.createTemplate';
import getTemplateDetails from '@salesforce/apex/FilesBiSyncController.getTemplateDetails';
import updateFolder from '@salesforce/apex/FilesBiSyncController.updateFolder';
import deleteFolder from '@salesforce/apex/FilesBiSyncController.deleteFolder';
import deleteFile from '@salesforce/apex/FilesBiSyncController.deleteFile';
import sendErrorEmail from '@salesforce/apex/FilesBiSyncController.sendErrorEmail';
import getEmailTemplateDetails from '@salesforce/apex/FilesBiSyncController.getEmailTemplateDetails';
import getSharePointFilePublicURL from '@salesforce/apex/FilesBiSyncController.getSharePointFilePublicURL';
import massDeleteFileAndFolder from '@salesforce/apex/FilesBiSyncController.massDeleteFileAndFolder';
import sendEmail from '@salesforce/apex/FilesBiSyncController.sendEmail';


export default class FilesBiSync extends LightningElement {

    @api recordId;
    @api currentFolderNotAvailable = false;
    @api currentFolderDetails = {};
    @api fileSettings = {};
    @api searchedResults = {};
    @api isLoaded = false;
    @api isCreateFolder = false;
    @api newFolderName = '';
    @api isUpdateFolder = false;
    @api updateFolderDetails = {};
    @api isDeleteFolder = false;
    @api isDeleteFile = false;
    @api deleteDetails = {};
    @api downloadDetails={};
    @api isCreateTemplateFolder = false;
    @api templateFolderDetails = {};
    @api modelTitle = '';
    @api currentFolderUri = '';
    @api folderPath = [];
    @api searchKey = '';
    @api errorMessage = '';
    @api folderNameValidation = '';
    //spclCharsNotAllowed = /[#%*|\:"<>?/]/g;
    baseUrl;
    rootFolderUri;
    sharePointLogo = FileBiSyncImages+'/logos/SharePointLogo.svg';
	isDropdownOnBlur = true;
    @api params =  {
        host: "", //"https://test.sharepoint.com/sites/mysite"
        folder: "", //"/sites/mysite/Shared Documents/Test%20Document"
        chunksize: 100000000, //File chunked by 100MB
        accesstoken: ""
    }
    @api isUploadFiles = false;
    @api uploadFiles = [];
    @api isFilesUploading = false;
    @api prop1;

    languageTemplates = [];
    languages= [];
    selectedLanguage;
    selectedTemplate;
    selectedTemplateSubject;
    selectedURI = [];
    showFileShareCcRecipient = false;
    @api isFileshare = false;
    toRecipients;
    ccRecipients;
    fileLinks;
    selectedFiles= [];
    urlMap;
	@api isDeleteSelected = false;
    @api isDownloadSelected =false;
    @api isDownloadFile =false;
    
    connectedCallback(){
        this.getRootFolderDetails();
    }

    renderedCallback(){
        this.template.querySelector('[data-id="moreOptions"]').className = 'slds-dropdown-trigger slds-dropdown-trigger_click slds-is-close slds-m-horizontal_xx-small slds-float_right';
        console.log('renderedCallback');
    }

    get loadSpinner(){
        return !this.isLoaded;
    }

    get showDetails(){
        return this.isLoaded;
    }

    get showModel(){
        return this.isCreateFolder || this.isUpdateFolder || this.isDeleteFolder || this.isDeleteFile || this.isCreateTemplateFolder || this.isUploadFiles || this.isFileshare || this.isDeleteSelected || this.isDownloadSelected || this.isDownloadFile;
    }

    get uploadedFilesStatus(){
        var uploadCompletedCount = 0;
        var validFileCount = 0;
        for(let index in this.uploadFiles){
            var file = this.uploadFiles[index];
            if(file.isComplete)
                uploadCompletedCount = uploadCompletedCount+1;
            if(file.validFile)
                validFileCount = validFileCount+1;
        }
        return uploadCompletedCount+' of '+this.uploadFiles.length+' files uploaded';
    }

    get invalidFileMessage(){
        var invalidFileCount = 0;
        var uploadFailedCount = 0;
        for(let index in this.uploadFiles){
            var file = this.uploadFiles[index];
            if(!file.validFile)
                invalidFileCount = invalidFileCount+1;
            if(file.isFailed)
                uploadFailedCount = uploadFailedCount+1;
        }
        var message = invalidFileCount!=0 ? invalidFileCount+' file(s) contains special characters in file name. ' : "";
        message = message + (uploadFailedCount!=0 ? ''+uploadFailedCount+' file(s) failed to upload. Reupload again.' : "");
        return message;
    }

    get closeUploadFiles(){
        var invalidFileCount = 0;
        var uploadFailedCount = 0;
        var uploadCompletedCount = 0;
        for(let index in this.uploadFiles){
            var file = this.uploadFiles[index];
            if(!file.validFile)
                invalidFileCount = invalidFileCount+1;
            else if(file.isComplete)
            uploadCompletedCount = uploadCompletedCount+1;
            else if(file.isFailed)
                uploadFailedCount = uploadFailedCount+1;
        }
        if(uploadFailedCount==0) return false;
        return this.uploadFiles.length == (invalidFileCount + uploadCompletedCount + uploadFailedCount);
    }

    get exception(){
        return this.errorMessage.length >0;
    }

    getRootFolderDetails(){
        this.isLoaded = false;
        getDetails({ recordId:this.recordId })
        .then(result => {
            //console.log('Result -->'+JSON.stringify(result));
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            console.log('error:'+this.currentFolderDetails.errorMessage);
            if(this.currentFolderDetails.errorMessage!=null){
                this.errorMessage = this.currentFolderDetails.errorMessage;
                return;
            }
            if(this.currentFolderDetails.URI==undefined || this.currentFolderDetails.URI==null)
                this.currentFolderNotAvailable = true;
            this.fileSettings = this.currentFolderDetails.fileSettings;
            this.rootFolderUri = this.currentFolderDetails.URI;
            this.currentFolderUri = this.currentFolderDetails.URI;
            this.baseUrl = this.currentFolderDetails.baseUrl;
            this.params.host = this.currentFolderDetails.fileStorage.Site_Name__c;
            this.params.folder = this.currentFolderDetails.serverRelativeUrl;
            this.params.accesstoken = this.currentFolderDetails.fileStorage.SharePoint_Access_Token__c;
            var folderName = 'Root Folder';
            var pathWidth = folderName.length<=25 ? folderName.length*7.5 : 150;
            var temp = {folderName : folderName, uri : this.currentFolderUri, pathStyle : pathWidth+"px", isLastFolder : true};
            this.folderPath.push(temp);
            var files = [];
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                file.isSelected = false;
                var fileType = file.fileType;
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
                if(fileType!='sfdb')
                {
                   //delete this.currentFolderDetails.files[key];
                   files.push(file);
                }
            }
            this.currentFolderDetails.files = files;
            for(let key in this.currentFolderDetails.folders){
                var folder = this.currentFolderDetails.folders[key];
                folder.name = folder.name.replaceAll('{34}','"').replaceAll('{35}','#').replaceAll('{42}','*').replaceAll('{58}',':').replaceAll('{60}','<').replaceAll('{62}','>').replaceAll('{63}','?').replaceAll('{47}','/').replaceAll('{92}','\\\\').replaceAll('{124}','|').replaceAll('{37}','%');
            }
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = '';
            this.isLoaded = true;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.isLoaded = true;
        });
    }

    sortFilesAndFoldersAsc(){
        //sort Folders
        var folders = this.searchedResults.folders;
        if(folders!=undefined && folders!=null){
            var unordered = {};
            for(let index in folders){
                unordered[folders[index].name] = folders[index];
            }
            const ordered = Object.keys(unordered).sort().reduce(
                (obj, key) => { 
                    obj[key] = unordered[key]; 
                    return obj;
                }, 
                {}
            );
            this.searchedResults.folders = Object.values(ordered);
        }
        //sort Files
        var files = this.searchedResults.files;
        if(files!=undefined && files!=null){
            var unordered = {};
            for(let index in files){
                unordered[files[index].name] = files[index];
            }
            const ordered = Object.keys(unordered).sort().reduce(
                (obj, key) => { 
                    obj[key] = unordered[key]; 
                    return obj;
                }, 
                {}
            );
            this.searchedResults.files = Object.values(ordered);
        }
    }

    getFoldersDetails(event){
        this.selectedURI =[];   // to clear selected files for sharing from current opened folder before opening new folder
        this.isLoaded = false;
        var uri;
        if(event!=null && event!=undefined)
            uri = event.currentTarget.dataset.id;
        else
            uri = this.currentFolderUri;
        //console.log('uri:'+uri);
        getFilesAndFolders({ uri:uri })
        .then(result => {
            //console.log('Result -->'+JSON.stringify(result));
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            this.currentFolderUri = this.currentFolderDetails.URI;
            this.params.folder = this.currentFolderDetails.serverRelativeUrl;
            var files = [];
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                var fileType = file.fileType;
                console.log('filetype: '+fileType);
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
                if(fileType!='sfdb')
                {
                   //delete this.currentFolderDetails.files[key];
                   files.push(file);
                }
            }
            this.currentFolderDetails.files = files;
            for(let key in this.currentFolderDetails.folders){
                var folder = this.currentFolderDetails.folders[key];
                folder.name = folder.name.replaceAll('{34}','"').replaceAll('{35}','#').replaceAll('{42}','*').replaceAll('{58}',':').replaceAll('{60}','<').replaceAll('{62}','>').replaceAll('{63}','?').replaceAll('{47}','/').replaceAll('{92}','\\\\').replaceAll('{124}','|').replaceAll('{37}','%');
            }
            var folderAddedInPath = false;
            var folderFoundIndex;
            for(let index in this.folderPath){
                var path = this.folderPath[index];
                if(path.uri==this.currentFolderUri){
                    folderAddedInPath = true;
                    folderFoundIndex = index;
                    path.isLastFolder = true;
                    break;
                }
                path.isLastFolder = false;
            }
            if(!folderAddedInPath){
                var folderName = this.currentFolderDetails.name;
                var pathWidth = folderName.length<=25 ? folderName.length*7.5 : 150;
                var temp = {folderName : folderName , uri : this.currentFolderUri, pathStyle : pathWidth+"px", isLastFolder : true};
                this.folderPath.push(temp);
            }
            if(folderAddedInPath && folderFoundIndex < this.folderPath.length-1){
                var index = parseInt(folderFoundIndex);
                this.folderPath.splice(index+1, this.folderPath.length-index-1);
            }
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = '';
            this.isLoaded = true;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.isLoaded = true;
        });
    }

    handleUploadFinished(event){
        this.isLoaded = false;
        const uploadedFiles = event.detail.files;
        var contentVersionIds = [];
        for(let index in uploadedFiles){
            contentVersionIds.push(uploadedFiles[index].contentVersionId);
        }

        uploadFiles({ uri:this.currentFolderUri, contentVersionIds: contentVersionIds })
        .then(result => {
            //console.log('Result -->'+JSON.stringify(result));
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            this.currentFolderUri = this.currentFolderDetails.URI;
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                var fileType = file.fileType;
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
            }
            this.newFolderName = '';
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = '';
            this.isLoaded = true;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.newFolderName = '';
            this.isLoaded = true;
        });
    }

    handleInputFileChange(event) {
        if(event.target.files.length > 0) {
            var validfilesCount = 0;
            this.isUploadFiles = true;
            this.modelTitle = 'Upload Files';
            for(let i=0;i<event.target.files.length;i++){
                var fileContent = event.target.files[i];
                var fileSize = fileContent.size/1024/1024 > 1 ? (fileContent.size/1024/1024).toFixed(1)+'MB' : (fileContent.size/1024).toFixed(1)+'KB';
                var spclCharsNotAllowed = /[#%*|\:"<>?/]/g;
                var isvalidFile = !spclCharsNotAllowed.test(fileContent.name);
                //var isvalidFile = true;
                var docType = "/_slds/icons/doctype-sprite/svg/symbols.svg#unknown";
                var temp = {name:fileContent.name, fileSymbol:docType, size:fileSize, uploadProgress:0, validFile: isvalidFile, isComplete:false, isCancelled:false, isFailed:false};
                this.uploadFiles.push(temp);
                if(isvalidFile){
                    validfilesCount++;
                    this.initiateFileUpload(fileContent);
                }
            }
            this.isFilesUploading = validfilesCount>0;
        }
    }

    initiateFileUpload(file) {
        console.log('Inside initiateFileUpload');
        var fileName = file.name;
        var url = `${this.params.host}/_api/web/GetFolderByServerRelativeUrl('${this.encodeURI(this.params.folder)}')/Files/add(url='${this.encodeURI(fileName)}',overwrite=true)`;
        console.log('URL: '+url);
        let xhttp = new XMLHttpRequest();
        xhttp.open("POST", url, true);
        xhttp.setRequestHeader("Authorization", "Bearer " + this.params.accesstoken);
        xhttp.setRequestHeader("accept", "application/json;odata=verbose");
        xhttp.send();
        xhttp.onload = () => {
            if (xhttp.status != 200) {
                console.log(`Create File Error onLoad - Satus: ${xhttp.status}: ${xhttp.statusText}`);
                //this.showNotification('error', 'Failed to upload file(s)', `Satus: ${xhttp.status} - ${xhttp.statusText}`);
                this.showNotification('error', 'Failed to upload file(s)', '');
                for(let fileIndex in this.uploadFiles){
                    var uploadedfile = this.uploadFiles[fileIndex];
                    if(uploadedfile.name==fileName){
                        uploadedfile.isFailed = true;
                    }
                }
            }
        };
        xhttp.onerror = () => {
            console.log(`Create File Error onError - Status: ${xhttp.status}: ${xhttp.statusText}`);
            this.showNotification('error', 'Failed to upload file(s)', 'Reupload the file(s) again or contact system administrator');
            for(let fileIndex in this.uploadFiles){
                var uploadedfile = this.uploadFiles[fileIndex];
                if(uploadedfile.name==fileName){
                    uploadedfile.isFailed = true;
                }
            }
        };
        xhttp.onloadend = () => {console.log('Status:');};
        xhttp.onreadystatechange = () => {
            //console.log('Status: '+xhttp.status+ '\n statusText:'+xttp.statusText+'\n readyState:'+xhttp.readyState);
            if (xhttp.readyState === 4) {
                var response = typeof xhttp.responseText !== "undefined"
                ? JSON.parse(xhttp.responseText)
                : "";
                if(response.error){
                    console.log('response:'+JSON.stringify(response));
                    for(let fileIndex in this.uploadFiles){
                        var uploadedfile = this.uploadFiles[fileIndex];
                        if(uploadedfile.name==fileName){
                            uploadedfile.isFailed = true;
                        }
                    }
                    var errorMessage = '<br/>Record Id: '+this.recordId+'<br/>File Name: '+fileName+'<br/>Folder: '+this.params.folder+'<br/>URL: '+url+'<br/>Error: '+JSON.stringify(response);
                    sendErrorEmail({ subjectReason:'create file while uploading', exceptionMessage:errorMessage});
                    return;
                }
                
                var offset = 0;
                // the total file size in bytes...
                var total = file.size;
                // 100MB Chunks as represented in bytes (if the file is less than 100 MB, seperate it into two chunks of 80% and 20% the size)...
                //let length = this.params.chunksize > total ? total * 0.8 : this.params.chunksize;
                var fileSizeInMB = total/1024/1024;
                var fileChunckDivision = fileSizeInMB<2 ? 0.8 : fileSizeInMB<4 ? 0.5 : fileSizeInMB<10 ? 0.25 : 0.2;
                console.log('fileChunckDivision: '+fileChunckDivision);
                var length = this.params.chunksize > total ? total * fileChunckDivision : this.params.chunksize;
                let chunks = [];
                while (offset < total) {
                    //if we are dealing with the final chunk, we need to know...
                    if (offset + length > total) {
                        length = total - offset;
                    }
                    
                    //work out the chunks that need to be processed and the associated REST method (start, continue or finish)
                    chunks.push({
                        offset: offset,
                        length: length,
                        method: this.getUploadMethod(offset, length, total)
                    });

                    offset += length;
                }
  
                //each chunk is worth a percentage of the total size of the file...
                const chunkPercentage = parseFloat(total / chunks.length / total) * 100;

                if (chunks.length > 0) {
                    //the unique guid identifier to be used throughout the upload session
                    const id = this.createGuid();

                    //Start the upload - send the data to SP
                    this.uploadFile(
                        file,
                        id,
                        this.params.folder,
                        file.name,
                        chunks,
                        0,
                        0,
                        chunkPercentage
                    );
                }
            }
        };
    }

    encodeURI(url){
        var encodedURI = encodeURIComponent(url);
        encodedURI = encodedURI.replaceAll('\'','\'\'');
        return encodedURI;
    }

    uploadFile (
        file,
        id,
        libraryPath,
        fileName,
        chunks,
        index,
        byteOffset,
        chunkPercentage
    ) {
        console.log('Inside uploadFile');
        //we slice the file blob into the chunk we need to send in this request (byteOffset tells us the start position)
        let chunk = chunks[index];
        const data = this.convertFileToBlobChunks(file, byteOffset, chunk);
        let offset = chunk.offset === 0 ? "" : ",fileOffset=" + byteOffset;
        var encodedFileName = this.encodeURI(fileName);
        var encodedlibraryPath = this.encodeURI(libraryPath);
        let targetURL = encodedlibraryPath + "/" + encodedFileName;
        //targetURL = targetURL.replaceAll(' ','%20').replaceAll('/','%2F');
        let endpoint = `${this.params.host}/_api/web/getfilebyserverrelativeurl('${targetURL}')/${chunk.method}(uploadId='${id}'${offset})`;
        console.log('EndPoint: '+endpoint);
        let xhttp = new XMLHttpRequest();
        xhttp.open("POST", endpoint, true);
        xhttp.setRequestHeader("Authorization", "Bearer " + this.params.accesstoken);
        xhttp.setRequestHeader("Accept", "application/json;odata=verbose");
        xhttp.setRequestHeader("Content-Type", "application/octet-stream");
        xhttp.send(data);
        xhttp.onload = () => {
            if (xhttp.status != 200) {
                console.log(`Upload onLoad - Satus: ${xhttp.status}: ${xhttp.statusText}`);
                this.showNotification('error', 'Failed to upload file(s)', `Satus: ${xhttp.status} - ${xhttp.statusText}`);
                for(let fileIndex in this.uploadFiles){
                    var uploadedfile = this.uploadFiles[fileIndex];
                    if(uploadedfile.name==fileName){
                        uploadedfile.isFailed = true;
                    }
                }
            }
        };
        xhttp.onerror = () => {
            //alert("Error Status: " + e.target.status);
            console.log(`Upload onError - Status: ${xhttp.status}: ${xhttp.statusText}`);
            this.showNotification('error', 'Failed to upload file(s)', 'Reupload the file(s) again or contact system administrator');
            for(let fileIndex in this.uploadFiles){
                var uploadedfile = this.uploadFiles[fileIndex];
                if(uploadedfile.name==fileName){
                    uploadedfile.isFailed = true;
                }
            }
        };
        xhttp.onreadystatechange = () => {
            if (xhttp.readyState === 4) {
                const isFinished = index === chunks.length - 1;

                if (!isFinished) {
                    //the response value is a string of JSON (ugly) which we need to consume to find the offset
                    const response =
                        typeof xhttp.responseText !== "undefined"
                            ? JSON.parse(xhttp.responseText)
                            : "";
                    if(response.error!=undefined){
                        console.log('response:'+JSON.stringify(response));
                        for(let fileIndex in this.uploadFiles){
                            var uploadedfile = this.uploadFiles[fileIndex];
                            if(uploadedfile.name==fileName){
                                uploadedfile.isFailed = true;
                            }
                        }
                        var errorMessage = '<br/>Record Id: '+this.recordId+'<br/>File Name: '+fileName+'<br/>Folder: '+this.params.folder+'<br/>URL: '+endpoint+'<br/>Error: '+JSON.stringify(response);
                        sendErrorEmail({ subjectReason:'upload file', exceptionMessage:errorMessage});
                        this.removeFileFromSharePoint(fileName);
                        return;
                    }

                    //depending on the position in the upload, the response string (JSON) can differ!
                    if (typeof response.d.StartUpload !== "undefined") {
                        byteOffset = parseInt(response.d.StartUpload, 10);
                    } else if (typeof response.d.ContinueUpload !== "undefined") {
                        byteOffset = parseInt(response.d.ContinueUpload, 10);
                    }
                }

                index += 1;

                const percentageComplete = isFinished ? 100 : Math.round(index * chunkPercentage);
                var uploadCompletedCount = 0;
                var validFileCount=0;
                for(let fileIndex in this.uploadFiles){
                    var uploadedfile = this.uploadFiles[fileIndex];
                    if(uploadedfile.name==fileName){
                        uploadedfile.uploadProgress = percentageComplete;
                        uploadedfile.isComplete = isFinished;
                    }
                    if(uploadedfile.isComplete)
                        uploadCompletedCount++;
                    if(uploadedfile.validFile)
                        validFileCount++;
                }
                
                this.isFilesUploading = uploadCompletedCount!=validFileCount;
                if(!this.isFilesUploading){
                    this.getFoldersDetails();
                }

                //More chunks to process before the file is finished, continue
                if (index < chunks.length) {
                    this.uploadFile(
                        file,
                        id,
                        libraryPath,
                        fileName,
                        chunks,
                        index,
                        byteOffset,
                        chunkPercentage
                    );
                } else {
                    //setLoaderMessage(false);
                }
            }
        };
    }

    removeFileFromSharePoint(fileName){
        console.log('Inside Delete File');
        var spSite=this.params.host.split("com").slice(1,4).join("/");
        var folder = this.params.folder.replace(spSite,'');
        var endpoint = `${this.params.host}/_api/web/GetFolderByServerRelativeUrl('${this.encodeURI(folder)}')/Files('${this.encodeURI(fileName)}')/recycle`;
        let xhttp = new XMLHttpRequest();
        xhttp.open("DELETE", endpoint, true);
        xhttp.setRequestHeader("Authorization", "Bearer " + this.params.accesstoken);
        xhttp.setRequestHeader("Accept", "application/json;odata=verbose");
        xhttp.send();
        xhttp.onload = () => {
            if (xhttp.status != 200) {
                console.log(`Delete Error onLoad - Satus: ${xhttp.status}: ${xhttp.statusText}`);
            }
        };
        xhttp.onerror = () => {
            //alert("Error Status: " + e.target.status);
            console.log(`Delete Error onError - Status: ${xhttp.status}: ${xhttp.statusText}`);
        };
        xhttp.onreadystatechange = () => {
            if (xhttp.readyState === 4) {
                const response =
                        typeof xhttp.responseText !== "undefined"
                            ? JSON.parse(xhttp.responseText)
                            : "";
                if(response.error!=undefined){
                    console.log('response:'+JSON.stringify(response));
                    var errorMessage = '<br/>Record Id: '+this.recordId+'<br/>File Name: '+fileName+'<br/>Folder: '+this.params.folder+'<br/>URL: '+endpoint+'<br/>Error: '+JSON.stringify(response);
                    sendErrorEmail({ subjectReason:'remove unuploaded file', exceptionMessage:errorMessage});
                    return;
                }
                console.log('Removed unuploaded file');
                for(let fileIndex in this.uploadFiles){
                    var uploadedfile = this.uploadFiles[fileIndex];
                    if(uploadedfile.name==fileName){
                        uploadedfile.isFailed = true;
                    }
                }
                var invalidFileCount = 0;
                var uploadFailedCount = 0;
                var uploadCompletedCount = 0;
                for(let index in this.uploadFiles){
                    var file = this.uploadFiles[index];
                    if(!file.validFile)
                        invalidFileCount = invalidFileCount+1;
                    else if(file.isComplete)
                    uploadCompletedCount = uploadCompletedCount+1;
                    else if(file.isFailed)
                        uploadFailedCount = uploadFailedCount+1;
                }
                var totalFiles = invalidFileCount + uploadCompletedCount + uploadFailedCount;
                console.log('totalFiles: '+totalFiles);
                if(this.uploadFiles.length == totalFiles){
                    this.getFoldersDetails();
                }
                
            }
        }
    }

    getUploadMethod(offset, length, total) {
        console.log(`offset:${offset}, Length:${length}, Total:${total}`);
        if (offset + length + 1 > total) {
            return "finishupload";
        } else if (offset === 0) {
            return "startupload";
        } else if (offset < total) {
            return "continueupload";
        }
        return null;
    }

    convertFileToBlobChunks(result, byteOffset, chunkInfo) {
        let blobData =
            chunkInfo.method === "finishupload"
                ? result.slice(byteOffset)
                : result.slice(byteOffset, byteOffset + chunkInfo.length);
        return blobData;
    }

    createGuid(){
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
            var r = (Math.random() * 16) | 0,
                v = c === "x" ? r : (r & 0x3) | 0x8;
            return v.toString(16);
        });
    }

    deleteFolderModelOpen(event){
        this.modelTitle = 'Delete Folder';
        var uri = event.currentTarget.dataset.id;
        for(let index in this.currentFolderDetails.folders){
            if(this.currentFolderDetails.folders[index].URI == uri){
                this.deleteDetails = this.currentFolderDetails.folders[index];
                break;
            }
        }
        this.isDeleteFolder = true;
    }

    deleteFolder(event){
      /*  this.isLoaded = false;
        //var uri = event.currentTarget.dataset.id;
        this.isDeleteFolder = false;
        var uri = this.currentFolderUri;
        uri = uri.replaceAll(' ','%20');
        window.open(uri, "_blank");
        this.deleteDetails = {};
        this.isLoaded = true; */
        this.isLoaded = false;
        deleteFolder({ uri:this.deleteDetails.URI })
        .then(result => {
            //console.log('Result -->'+JSON.stringify(result));
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            this.currentFolderUri = this.currentFolderDetails.URI;
            var files = [];
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                var fileType = file.fileType;
                if(fileType!='sfdb')
                {
                   //delete this.currentFolderDetails.files[key];
                   files.push(file);
                }
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
            }
            this.currentFolderDetails.files = files;
            for(let key in this.currentFolderDetails.folders){
                var folder = this.currentFolderDetails.folders[key];
                folder.name = folder.name.replaceAll('{34}','"').replaceAll('{35}','#').replaceAll('{42}','*').replaceAll('{58}',':').replaceAll('{60}','<').replaceAll('{62}','>').replaceAll('{63}','?').replaceAll('{47}','/').replaceAll('{92}','\\\\').replaceAll('{124}','|').replaceAll('{37}','%');
            }
            this.newFolderName = '';
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = ''; 
            this.deleteDetails = {};
            this.isLoaded = true;
            this.isDeleteFolder = false;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.newFolderName = '';
            this.deleteDetails = {};
            this.isLoaded = true;
            this.isDeleteFolder = false;
        });
    }

    deleteFileModelOpen(event){
        this.modelTitle = 'Delete File';
        var uri = event.currentTarget.dataset.id;
        for(let index in this.currentFolderDetails.files){
            if(this.currentFolderDetails.files[index].URI == uri){
                this.deleteDetails = this.currentFolderDetails.files[index];
                break;
            }
        }
        this.isDeleteFile = true;
    }

    deleteFile(event){
        //var uri = event.currentTarget.dataset.id;
      /*  this.isLoaded = false;
        this.isDeleteFile = false;
        var uri = this.currentFolderUri.replaceAll(' ','%20');
        window.open(uri, "_blank");
        this.isLoaded = true; */
        this.isLoaded = false;
        deleteFile({ uri:this.deleteDetails.URI})
        .then(result => {
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            this.currentFolderUri = this.currentFolderDetails.URI;
            var files = [];
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                var fileType = file.fileType;
                if(fileType!='sfdb')
                {
                   //delete this.currentFolderDetails.files[key];
                   files.push(file);
                }
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
            }
            this.currentFolderDetails.files = files;
            for(let key in this.currentFolderDetails.folders){
                var folder = this.currentFolderDetails.folders[key];
                folder.name = folder.name.replaceAll('{34}','"').replaceAll('{35}','#').replaceAll('{42}','*').replaceAll('{58}',':').replaceAll('{60}','<').replaceAll('{62}','>').replaceAll('{63}','?').replaceAll('{47}','/').replaceAll('{92}','\\\\').replaceAll('{124}','|').replaceAll('{37}','%');
            }
            this.newFolderName = '';
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = '';
            this.deleteDetails = {};
            this.isLoaded = true;
            this.isDeleteFile = false;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.newFolderName = '';
            this.deleteDetails = {};
            this.isLoaded = true;
            this.isDeleteFile = false;
        });
    }

    //selected delete method
   /* deleteSelectedModelOpen(event){
        this.modelTitle = 'Delete Selected';
        var uri = event.currentTarget.dataset.id;
        for(let index in this.currentFolderDetails.files){
            if(this.currentFolderDetails.files[index].URI == uri){
                this.deleteDetails = this.currentFolderDetails.files[index];
                break;
            }
        }
        this.isDeleteSelected= true;
    } */

    deleteSelectedModelOpen(){
        if(this.selectedURI.length == 0){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '',
                    message: 'File must be selected to delete',
                    variant: 'info'
                })
            );
        }
        else{
            this.modelTitle = 'Delete Selected Files';
            this.isDeleteSelected= true;
            this.handleSearch({detail:{value:''}});
        }
    }

     deleteSelected(){
        var uri=[];
        this.isDeleteSelected= false;
        this.isLoaded = false;
         massDeleteFileAndFolder({ folderUrlList:uri, fileUrlList: this.selectedURI})
        .then(result => {
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            this.currentFolderUri = this.currentFolderDetails.URI;
            var files = [];
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                var fileType = file.fileType;
                if(fileType!='sfdb')
                {
                   //delete this.currentFolderDetails.files[key];
                   files.push(file);
                }
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
            }
            this.currentFolderDetails.files = files;
            for(let key in this.currentFolderDetails.folders){
                var folder = this.currentFolderDetails.folders[key];
                folder.name = folder.name.replaceAll('{34}','"').replaceAll('{35}','#').replaceAll('{42}','*').replaceAll('{58}',':').replaceAll('{60}','<').replaceAll('{62}','>').replaceAll('{63}','?').replaceAll('{47}','/').replaceAll('{92}','\\\\').replaceAll('{124}','|').replaceAll('{37}','%');
            }
            this.newFolderName = '';
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = '';
            this.deleteDetails = {};
            this.isLoaded = true;
            
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.newFolderName = '';
            this.deleteDetails = {};
            this.isLoaded = true;
            this.isDeleteSelected = false;
        });
        this.handleSearch({detail:{value:''}});
        this.selectedURI =[];
    }

    downloadSelectedModelOpen(){
        if(this.selectedURI.length == 0){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '',
                    message: 'File must be selected to download',
                    variant: 'info'
                })
            );
        }
        else{
            this.modelTitle = 'Download Selected';
            this.isDownloadSelected= true;
            this.handleSearch({detail:{value:''}});
        }
    }

    downloadFileModelOpen(event){
        
            this.modelTitle = 'Download File';
            var uri = event.currentTarget.dataset.id;
        for(let index in this.currentFolderDetails.files){
            if(this.currentFolderDetails.files[index].serverRelativeUrl == uri){
                this.downloadDetails = this.currentFolderDetails.files[index];
                break;
            }
        }
            this.isDownloadFile= true;
        
    }

   /* downloadSelected(){
        var serverRelativeUrls = [];
        this.selectedURI.forEach(element=>{
            console.log('element-->',element);
            var spSite=element.split("com").slice(1,4).join("/");
            serverRelativeUrls.push(spSite);
            
        });
        console.log('Url list::'+serverRelativeUrls);
        serverRelativeUrls.forEach(url => {
            this.download(url);
           
        });
        for(let index in this.currentFolderDetails.files ){
            this.currentFolderDetails.files[index].isSelected = false;
            
        }
        

    } */
    downloadSelected() {
        var serverRelativeUrls = [];
        this.selectedURI.forEach(element => {
          console.log('element-->', element);
          var spSite = element.split("com").slice(1, 4).join("/");
          serverRelativeUrls.push(spSite);
        });
        console.log('Url list:', serverRelativeUrls);
      
        // Create an array of Promises for each download
        var downloadPromises = serverRelativeUrls.map(url => {
          return this.download(url);
        });
      
        // Wait for all Promises to resolve
        

        Promise.all(downloadPromises)
  .then(() => {
    for (let index in this.currentFolderDetails.files) {
      this.currentFolderDetails.files[index].isSelected = false;
    }
  })
  .catch(error => {
    console.error('Failed to open new windows for the following URLs:', error);
  });
  for (let index in this.currentFolderDetails.files) {
    this.currentFolderDetails.files[index].isSelected = false;
  }
  
      }
      
    downloadSingleFile(event){
        var serverRelativeUrl = this.downloadDetails.serverRelativeUrl;
        console.log('Url::'+serverRelativeUrl);
        this.download(serverRelativeUrl);
    }
    download(url) {

        this.isDownloadSelected= false;
        this.isDownloadFile=false;
        this.downloadDetails=false;
        
        return new Promise((resolve, reject) => {
          var hosturl = new URL(this.params.host).origin;
          console.log('host:', hosturl);
          var urlso = hosturl + url;
          var urls = this.params.host + '_layouts/15/download.aspx?SourceUrl=' + urlso;
          console.log('durl:', urls);
          var newWindow = window.open(urls, '_blank');
          if (newWindow) {
            // If the new window was successfully opened, resolve the Promise
            resolve();
            this.handleSearch({detail:{value:''}});
            this.selectedURI =[];
          } else {
            // If the new window failed to open, reject the Promise
            reject(new Error('Failed to open new window.'));
          }
        });
        
        
      }
    /*async download(url){
        var hosturl=new URL(this.params.host).origin;
        console.log('host:'+hosturl);
     var urlso=hosturl+url;
     var urls=this.params.host+'_layouts/15/download.aspx?SourceUrl='+urlso;
     console.log('durl::'+urls);
     window.open(urls,'_blank');

    }*/

    downloads(url){
        
        console.log('Url inside::'+url);
        var authToken = this.params.accesstoken;
        
        this.isDownloadSelected= false;
        this.isDownloadFile=false;
        this.downloadDetails=false;
          var endPointUri = `${this.params.host}_api/web/GetFileByServerRelativeUrl('${this.encodeURI(url)}')/$value`;
          var filenameSp = url.split("/").pop();
          var filename = filenameSp.replaceAll('%20',' ');
          
          fetch(endPointUri, {
            method: 'GET',
            headers: {
              'Authorization': 'Bearer ' + authToken,
              'Accept': 'application/json;odata=verbose'
            }
          })
          .then(response => {
            if (!response.ok) {
              throw new Error('Network response was not ok');
            }
            console.log('response'+response.body);
            return response.blob();
          })
          //.then(response => response.blob())
          .then(blob => {
            const url = window.URL.createObjectURL(new Blob([blob]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', filename);
            document.body.appendChild(link);
            console.log('durl::'+url);
            window.open(link.click(),'_blank');
            //link.click();
            window.URL.revokeObjectURL(url);
          })
          .catch(error => {
            console.error('Error downloading file: ', error);
          });
        
      
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Success',
            message: 'Files downloaded successfully!',
            variant: 'success'
          })
        );
        this.handleSearch({detail:{value:''}});
        this.selectedURI =[];
        
      }
      

    handleSearch(event){
        var searchKey = event.detail.value;
        this.searchKey = searchKey;
        //search Folders
        var folders = this.currentFolderDetails.folders;
        if(folders!=undefined && folders!=null){
            var matchedFolders = {};
            for(let index in folders){
                if(folders[index].name.toLowerCase().includes(searchKey.toLowerCase()))
                    matchedFolders[folders[index].name] = folders[index];
            }
            this.searchedResults.folders = Object.values(matchedFolders);
        }
        //search Files
        var files = this.currentFolderDetails.files;
        if(files!=undefined && files!=null){
            var matchedFiles = {};
            for(let index in files){
                if(files[index].name.toLowerCase().includes(searchKey.toLowerCase()))
                    matchedFiles[files[index].name] = files[index];
            }
            this.searchedResults.files = Object.values(matchedFiles);
        }
    }

    createFolderModelOpen(event){
        this.modelTitle = 'Create Folder';
        this.isCreateFolder = true;
        //this.toggleMoreOptionsVisibility();
    }

    handleFolderName(event){
        this.newFolderName = event.detail.value;
        var spclCharsNotAllowed = /[#%*|\:"<>?/]/g;
        if(spclCharsNotAllowed.test(this.newFolderName))
            this.folderNameValidation = 'Name cannot contain special characters #%*|\:"<>?/';
        else
            this.folderNameValidation = '';
    }

    createNewFolder(event){
        var spclCharsNotAllowed = /[#%*|\:"<>?/]/g;
        if(spclCharsNotAllowed.test(this.newFolderName)){
            this.folderNameValidation = 'Name cannot contain special characters #%*|\:"<>?/';
            return;
        }else if(this.newFolderName=='' || this.newFolderName==' '){
            this.folderNameValidation = 'Enter folder name';
            return;
        }
        this.isCreateFolder = false;
        this.isLoaded = false;
        createFolder({ uri:this.currentFolderUri, folderName: this.newFolderName })
        .then(result => {
            //console.log('Result -->'+JSON.stringify(result));
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            this.currentFolderUri = this.currentFolderDetails.URI;
            var files = [];
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                var fileType = file.fileType;
                if(fileType!='sfdb')
                {
                   //delete this.currentFolderDetails.files[key];
                   files.push(file);
                }
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
            }
            this.currentFolderDetails.files = files;
            for(let key in this.currentFolderDetails.folders){
                var folder = this.currentFolderDetails.folders[key];
                folder.name = folder.name.replaceAll('{34}','"').replaceAll('{35}','#').replaceAll('{42}','*').replaceAll('{58}',':').replaceAll('{60}','<').replaceAll('{62}','>').replaceAll('{63}','?').replaceAll('{47}','/').replaceAll('{92}','\\\\').replaceAll('{124}','|').replaceAll('{37}','%');
            }
            this.newFolderName = '';
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = '';
            this.folderNameValidation = '';
            this.isLoaded = true;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.newFolderName = '';
            this.isLoaded = true;
        });
    }

    createTemplateFolderModelOpen(event){
        this.isLoaded = false;
        getTemplateDetails({ recordId:this.recordId })
        .then(result => {
            //console.log('Result -->'+JSON.stringify(result));
            this.templateFolderDetails = JSON.parse(JSON.stringify(result));
            this.modelTitle = this.templateFolderDetails.objName+' Folder Template';
            this.modelTitle = this.modelTitle.replace('__c','');
            if(this.templateFolderDetails.foldersAvailable){
                this.templateFolderDetails.folderList = this.templateFolderDetails.folderList.sort();
            }
            for(let index in this.folderPath){
                if(this.folderPath[index].uri == this.currentFolderUri){
                    this.templateFolderDetails.currentFolderName = this.folderPath[index].folderName;
                    break;
                }
            }
            this.isCreateTemplateFolder = true;
            this.isLoaded = true;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.newFolderName = '';
            this.templateFolderDetails = {};
            this.isLoaded = true;
        });
    }

    createTemplateFolders(event){
        this.isCreateTemplateFolder = false;
        this.isLoaded = false;
        createTemplate({ uri:this.currentFolderUri, recordId:this.recordId })
        .then(result => {
            //console.log('Result -->'+JSON.stringify(result));
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            this.currentFolderUri = this.currentFolderDetails.URI;
            var files = [];
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                var fileType = file.fileType;
                if(fileType!='sfdb')
                {
                   //delete this.currentFolderDetails.files[key];
                   files.push(file);
                }
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
            }
            this.currentFolderDetails.files = files;
            for(let key in this.currentFolderDetails.folders){
                var folder = this.currentFolderDetails.folders[key];
                folder.name = folder.name.replaceAll('{34}','"').replaceAll('{35}','#').replaceAll('{42}','*').replaceAll('{58}',':').replaceAll('{60}','<').replaceAll('{62}','>').replaceAll('{63}','?').replaceAll('{47}','/').replaceAll('{92}','\\\\').replaceAll('{124}','|').replaceAll('{37}','%');
            }
            this.newFolderName = '';
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = ''; 
            this.deleteDetails = {};
            this.templateFolderDetails = {};
            this.isLoaded = true;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.newFolderName = '';
            this.deleteDetails = {};
            this.templateFolderDetails = {};
            this.isLoaded = true;
        });
    }

    updateFolderModelOpen(event){
        this.modelTitle = 'Rename Folder';
        var uri = event.currentTarget.dataset.id;
        for(let index in this.currentFolderDetails.folders){
            if(this.currentFolderDetails.folders[index].URI == uri){
                this.updateFolderDetails = this.currentFolderDetails.folders[index];
                break;
            }
        }
        this.isUpdateFolder = true;
    }

    handleUpdateFolderName(event){
        this.updateFolderDetails.name = event.detail.value;
        var spclCharsNotAllowed = /[#%*|\:"<>?/]/g;
        if(spclCharsNotAllowed.test(this.updateFolderDetails.name))
            this.folderNameValidation = 'Name cannot contain special characters #%*|\:"<>?/';
        else
            this.folderNameValidation = '';
    }

    updateFolder(event){
        var spclCharsNotAllowed = /[#%*|\:"<>?/]/g;
        if(spclCharsNotAllowed.test(this.updateFolderDetails.name)){
            this.folderNameValidation = 'Name cannot contain special characters #%*|\:"<>?/';
            return;
        }else if(this.updateFolderDetails.name=='' || this.updateFolderDetails.name==' '){
            this.folderNameValidation = 'Enter folder name';
            return;
        }
        this.isUpdateFolder = false;
        this.isLoaded = false;
        updateFolder({ uri:this.updateFolderDetails.URI, folderName: this.updateFolderDetails.name })
        .then(result => {
            //console.log('Result -->'+JSON.stringify(result));
            this.currentFolderDetails = JSON.parse(JSON.stringify(result));
            this.currentFolderUri = this.currentFolderDetails.URI;
            var files = [];
            for(let key in this.currentFolderDetails.files){
                var file = this.currentFolderDetails.files[key];
                var fileType = file.fileType;
                if(fileType!='sfdb')
                {
                   //delete this.currentFolderDetails.files[key];
                   files.push(file);
                }
                var docTypeIcon = (fileType=='gif' || fileType=='heic' || fileType=='heif' || fileType=='jpeg' || fileType=='jpg' || fileType=='jpe' || fileType=='mef' || fileType=='mrw' || fileType=='nef' || fileType=='nrw' || fileType=='orf' || fileType=='pano' || fileType=='pef' || fileType=='png' || fileType=='rw2' || fileType=='spm' || fileType=='tif' || fileType=='tiff' || fileType=='xbm' || fileType=='xcf') ? 'image' : fileType=='csv' ? 'csv' : fileType=='xlsx' ? 'excel' : fileType=='pdf' ? 'pdf' : fileType=='txt' ? 'txt' : (fileType=='doc' || fileType=='docx') ? 'word' : fileType=='zip' ? 'zip' : 'unknown';
                file.fileSymbol = "/_slds/icons/doctype-sprite/svg/symbols.svg#"+docTypeIcon;
            }
            this.currentFolderDetails.files = files;
            for(let key in this.currentFolderDetails.folders){
                var folder = this.currentFolderDetails.folders[key];
                folder.name = folder.name.replaceAll('{34}','"').replaceAll('{35}','#').replaceAll('{42}','*').replaceAll('{58}',':').replaceAll('{60}','<').replaceAll('{62}','>').replaceAll('{63}','?').replaceAll('{47}','/').replaceAll('{92}','\\\\').replaceAll('{124}','|').replaceAll('{37}','%');
            }
            this.updateFolderDetails = {};
            this.searchedResults = JSON.parse(JSON.stringify(this.currentFolderDetails));
            this.sortFilesAndFoldersAsc();
            this.currentFolderDetails = JSON.parse(JSON.stringify(this.searchedResults));
            this.searchKey = '';
            this.folderNameValidation = '';
            this.isLoaded = true;
        })
        .catch(error => {
            console.log(error);
            this.errorMessage = 'Something went wrong. Please contact system administrator.';
            this.updateFolderDetails = {};
            this.isLoaded = true;
        });

    }

   /* handleButtonClick(url) {
        var serverRelativeUrl = url;
      //  `${this.params.host}/_api/web/GetFolderByServerRelativeUrl('
        var endPointUri = `${this.params.host}_api/web/GetFileByServerRelativeUrl('${this.encodeURI(serverRelativeUrl)}')/$value`;
        var authToken = this.params.accesstoken;
        var filename = serverRelativeUrl.split("/").pop();
        fetch(endPointUri, {
            method: 'GET',
            headers: {
                'Authorization': 'Bearer ' + authToken,
                'Accept': 'application/json;odata=verbose'
            }
        })
        .then(response => response.blob())
        .then(blob => {
            const url = window.URL.createObjectURL(new Blob([blob]));
            var blobfile= JSON.stringify(blob);
            console.log('blob  '+ blobfile);
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', filename);
            document.body.appendChild(link);
            link.click();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'File downloaded successfully!',
                    variant: 'success'
                })
            );
        })
        .catch(error => {
            console.error('Error: ', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'File download failed: ' + error,
                    variant: 'error'
                })
            );
        });
    }
    */



    createUpdateDeleteFolderModelClose(){
        this.modelTitle = '';
        this.isCreateFolder = false;
        this.newFolderName = '';
        this.isUpdateFolder = false;
        this.updateFolderDetails = {};
        this.isDeleteFolder = false;
        this.isDeleteFile = false;
        this.deleteDetails = {};
        this.downloadDetails ={};
        this.isCreateTemplateFolder = false;
        this.templateFolderDetails = {};
        this.folderNameValidation = '';
        this.isUploadFiles = false;
        this.isFilesUploading = false;
        this.uploadFiles = [];
        this.isDeleteSelected=false;
        this.isDownloadSelected=false;
        this.isDownloadFile=false;
        if(this.isFileshare = true){
            console.log('files',this.currentFolderDetails.files);
            this.isFileshare = false;
            this.languageTemplates = [];
            this.languages =[];
            this.selectedTemplate ='';
            this.selectedTemplateSubject ='';
            this.ccRecipients = '';
            this.toRecipients = '';
            //this.selectedURI =[];
            this.showFileShareCcRecipient = false;
        }
       
    }

    previewFile(event){
        var serverRelativeUrl = event.currentTarget.dataset.id;
        var previewFileType1 = ['jpg','png','zip','svg','pdf'];
        var previewFileType2 = ['doc','docx','csv','xlsx','pptx','vsdx'];
        var url = this.baseUrl;
        var spSite=this.params.host.split("com").slice(1,4).join("/");
        for(let index in this.currentFolderDetails.files){
            var file = this.currentFolderDetails.files[index];
            if(file.serverRelativeUrl == serverRelativeUrl){
                if(previewFileType1.includes(file.fileType)){
                    var serverRelativeUrlEncoded = serverRelativeUrl.replaceAll(' ','%20').replaceAll('&','%26').replaceAll('\'','%27');
                    var parentserverRelativeUrlEncoded = this.currentFolderDetails.serverRelativeUrl.replaceAll(' ','%20').replaceAll('&','%26').replaceAll('\'','%27');
                    url = url + spSite+'Shared Documents/Forms/AllItems.aspx'+'?id='+serverRelativeUrlEncoded+'&parent='+parentserverRelativeUrlEncoded;
                }
                else if(previewFileType2.includes(file.fileType)){
                    var fileName = file.name.replaceAll(' ','%20').replaceAll('&','%26').replaceAll('\'','%27');
                    url = url + spSite+'_layouts/15/Doc.aspx'+'?sourcedoc={'+file.uniqueId+'}&file='+fileName+'&action=edit&mobileredirect=true';
                }
                else{
                    var url = this.baseUrl + serverRelativeUrl;
                }
                break;
            }
        }
        //var url = this.baseUrl + serverRelativeUrl;
        window.open(url, "_blank");
    }

    async filePreviewReadOnly(event){
        var serverRelativeUrl=[];
        serverRelativeUrl.push(event.currentTarget.dataset.id);
        var previewLink='';
        this.isLoaded=false;
        console.log('url::'+serverRelativeUrl);
        
       await getSharePointFilePublicURL({listURI:serverRelativeUrl})
        .then( response => {
            this.fileLinks = response;
            console.log('response-->',response.urlMap);
            this.urlMapPreview = JSON.parse(JSON.stringify(response.urlMap));
            console.log('reUrlmap-->',this.urlMapPreview );
        })
        .catch( error => {
           console.log('error-->',error);
        })
        serverRelativeUrl.forEach(element=>{
         previewLink = this.urlMapPreview[element];
        });
        console.log('link-->',previewLink );
        this.isLoaded=true;
        window.open(previewLink, "_blank");
    }

    openSharePointOnline(event){
        var uri = this.currentFolderUri;
        uri = uri.replaceAll(' ','%20');
        window.open(uri, "_blank");
    }

    showNotification(variant, title, message) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    toggleMoreOptionsVisibility(){
        var currentsection = this.template.querySelector('[data-id="moreOptions"]');
        if(currentsection){
            if (currentsection.className.search('slds-is-open') == -1) {
                currentsection.className = 'slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open slds-m-horizontal_xx-small slds-float_right';
            } else {
                currentsection.className = 'slds-dropdown-trigger slds-dropdown-trigger_click slds-is-close slds-m-horizontal_xx-small slds-float_right';
            }
        } 
    }
    moreLineItemOnMouseIn(){
        this.isDropdownOnBlur = false;
    }
    moreLineItemOnMouseOut(){
        this.isDropdownOnBlur = true;
    }
    dropdownOnBlur(){
        var currentsection = this.template.querySelector('[data-id="moreOptions"]');
        if(currentsection && this.isDropdownOnBlur == true){
            if (currentsection.className.search('slds-is-open') != -1) {             
                currentsection.className = 'slds-dropdown-trigger slds-dropdown-trigger_click slds-is-close slds-m-horizontal_xx-small slds-float_right';
            }
        } 
    }

    async shareFileModelOpen(){
        if(this.selectedURI.length == 0){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '',
                    message: 'File must be selected to share',
                    variant: 'info'
                })
            );
        }
        else{
        //this.isFileshare = true;
        this.isLoaded = false;
        this.modelTitle = 'Share Files';
        await this.getPublicLinks();
        console.log('check-->',this.showFileShare);
        getEmailTemplateDetails({})
            .then(result => {
                this.isFileshare = true;
                this.isLoaded = true;
                var res = JSON.parse(JSON.stringify(result)) 
                console.log('Temp Result-->',result);
                if(res!=null){
                   // console.log('Temp -->',res.emailTemplates)
                    var lan = [];
                    var languageTemplate = [];
                
                    for(let index in res){
                        var template = res[index];
                        if(template.DeveloperName.includes('File_Share')){
                            var language = template.DeveloperName.substring(template.DeveloperName.lastIndexOf('_')+1);
                            lan.push({label:language, value:language});
                            languageTemplate.push({language:language, template:template});
                        }
                    }
                    this.languages = [...this.languages,...lan];
                    this.languageTemplates = [...this.languageTemplates,...languageTemplate];
                    console.log('check contains-->',this.languages.includes('English'));

                    this.languages.forEach(element => {
                        if(element.label == 'English'){
                            this.selectedLanguage = 'English';
                            this.languageChange();
                            this.handleSearch({detail:{value:''}});
                        }
                    })
				}
			})
			.catch(error => {
                console.log('Error-->',error);
                this.isLoaded = true;
            })
        }
    }

     async getPublicLinks(){
        console.log('get file links-->',this.selectedFiles);
        console.log('get file links-->',this.selectedURI);
        var result = {};
       /* for (var i = 0; i < this.selectedFiles.length; i++) {
            result.push(this.selectedFiles[i]);
        }
        console.log('results-->',result);
        */
        await getSharePointFilePublicURL({listURI:this.selectedURI})
        .then( response => {
            this.fileLinks = response;
            console.log('response-->',response.urlMap);
            this.urlMap = JSON.parse(JSON.stringify(response.urlMap));
            console.log('response-->',this.urlMap );
        })
        .catch( error => {
           console.log('error-->',error);
        })
    }

    languageChange(event){
        if(event){
            this.selectedLanguage = event.target.value;
        }
        var fileHyperLinks = '';

        this.selectedURI.forEach(element=>{
            console.log('element-->',element);
            var filename = (element.substring(element.lastIndexOf('/')+1)).replaceAll('%20',' ');
            var link = this.urlMap[element];
            console.log('filename-->',filename);
            console.log('link-->',link);
            
            
            fileHyperLinks = fileHyperLinks + '<a href="'+link+'">'+filename+'</a><br/>';
        })

 /*       this.selectedURI.forEach(element => {
            this.fileLinks.forEach(ele=>{
                if(element.uri == ele.element.uri){
                    fileHyperLinks = fileHyperLinks + '<a href="'+ele.filePublicURL+'">'+element.Name+'</a><br/>';
                }
            })
        });*/

        this.languageTemplates.forEach(element => {
            if(this.selectedLanguage == element.language){
                this.selectedTemplate = element.template.HtmlValue +'<br/>'+fileHyperLinks;
                this.selectedTemplateSubject = element.template.Subject;
            }
        });
        
    }

    handleFileSelectionChange(event){
        
        console.log('handleFileSelectionChange-->');
        var uri = event.currentTarget.dataset.id;
        var select = event.currentTarget.checked;
        console.log('select-->',select);
                for(let index in this.currentFolderDetails.files ){
                    if( this.currentFolderDetails.files[index].URI == uri){
                        try {
                            let name = this.currentFolderDetails.files[index].name;
                            console.log('name-->',name);
                            this.currentFolderDetails.files[index].isSelected = select;
                            if(select){
                                
                                //this.selectedFiles.push(this.currentFolderDetails.files[index]);
                                this.selectedURI.push(uri.toString());
                                console.log('URI-->',this.selectedURI);
                            }
                            else{
                                
                                for(let key in this.selectedURI ){
                                    if(this.selectedURI[key] == uri){
                                        this.selectedURI.splice(key,1);
                                        console.log('URI-->',this.selectedURI);
                                    }
                                }
                                /*
                                for(let key in this.selectedFiles ){
                                    if(this.selectedFiles[key].name == name){
                                        this.selectedFiles.splice(key,1);
                                    }
                                }*/
                            }
                        }
                         catch (error) {
                            console.log('error-->',error);
                        }  
                        }
                }
    }
    handleEmailInputChange(event){
        var id = event.currentTarget.dataset.id;
        var value = event.target.value;
        if(id=='toRecipients'){
            this.toRecipients = value;
            console.log('to-->',this.toRecipients);
        }
        else if(id=='ccRecipients'){
            this.ccRecipients = value;
            console.log('cc-->',this.ccRecipients);
        }
        else if(id == 'emailSubject'){
            this.selectedTemplateSubject = value;
        }
        else if(id == 'emailBody'){
            this.selectedTemplate = value;
        }

    }
    addFileShareCcRicipient(){
        this.showFileShareCcRecipient = true;
    }

    shareFiles(){
        console.log('Share Clicked');
        var toRecipients = this.toRecipients;
        if(toRecipients==null || toRecipients==undefined || toRecipients.length==0){
            this.showNotification('error','Email Recipients cannot be empty','');
            return;
        }
        var toRecipientsList = toRecipients.split(',');
        const emailRegex=/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
        for(var index in toRecipientsList){
            if(toRecipientsList[index].length>0 && !toRecipientsList[index].match(emailRegex)){
                this.showNotification('error', 'Invalid email format', '"'+toRecipientsList[index]+'" is not a valid email.');
                return;
            }
        }
        if(toRecipientsList.length==0 || toRecipientsList.toString()==','){
            this.showNotification('error','Email Recipients cannot be empty','');
            return;
        }
        console.log('to recipients verified');
        var ccRecipients = this.ccRecipients;
        if(ccRecipients!=null && ccRecipients!=undefined && ccRecipients.length>0){
            var ccRecipientsList = ccRecipients.split(',');
            const emailRegex=/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
            for(var index in ccRecipientsList){
                if(ccRecipientsList[index].length>0 && !ccRecipientsList[index].match(emailRegex)){
                    this.showNotification('error','Invalid email format','"'+ccRecipientsList[index]+'" is not a valid email.');
                    return;
                }
            }
            if(ccRecipientsList.length==0 || ccRecipientsList.toString()==','){
                this.showNotification('error','Cc Recipients format is invalid','');
                return;
            }
        }
        console.log('cc recipients verified');
        var subject = this.selectedTemplateSubject;
        if(subject.length==0){
            this.showNotification('error','Subject cannot be empty','');
            return;
        }
        console.log('subject verified');
        var HtmlValue = this.selectedTemplate;
        if(HtmlValue.length==0){
            this.showNotification('error','Email body cannot be empty','');
            return;
        }
        HtmlValue = HtmlValue.replaceAll('</p><p>','<br/>').replaceAll('<br>','').replaceAll('<p>','').replaceAll('</p>','');
        console.log('body verified');
        console.log('Email send Initated');
        sendEmail({toRecipients:toRecipientsList,ccRecipients:ccRecipientsList,emailSubject:subject,emailContent:HtmlValue})
        .then((result) => {
            console.log('sendEmail Result',result);
            if(result==''){
                this.showNotification('success','Email sent','');
                this.selectedURI =[];
                for(let index in this.currentFolderDetails.files ){
                    this.currentFolderDetails.files[index].isSelected = false;
                    
                }
                this.handleSearch({detail:{value:''}});
                this.createUpdateDeleteFolderModelClose();
            }
            else{
                this.showNotification('info',result,'');
            }
            
        }).catch((error) => {
            console.log('Error:'+JSON.stringify(error));
            this.showNotification('error','Failed to send email','');
        });

    }
}