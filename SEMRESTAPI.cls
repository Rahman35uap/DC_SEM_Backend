Class SEM.SEMRESTAPI Extends %CSP.REST
{

/// ライセンス消費対策
Parameter UseSession As Integer = 0;

// FIX 1: Add parameter to force UTF-8 decoding for incoming requests

Parameter CHARSET = "UTF8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
        <Route Url="/signup" Method="POST" Call="AccountRegistration"/>
        <Route Url="/signin" Method="POST" Call="AccountLogin"/>
        
        <Route Url="/employees" Method="GET" Call="SEM.SEMEmployeeRESTAPI:GetAllEmployees"/>
        <Route Url="/employee/:id" Method="GET" Call="SEM.SEMEmployeeRESTAPI:GetEmployeeById"/>
        <Route Url="/employee" Method="POST" Call="SEM.SEMEmployeeRESTAPI:CreateEmployee"/>
        <Route Url="/employee/:id" Method="PUT" Call="SEM.SEMEmployeeRESTAPI:UpdateEmployee"/>
        <Route Url="/employee/:id" Method="DELETE" Call="SEM.SEMEmployeeRESTAPI:DeleteEmployee"/>
    </Routes>
}

ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    #dim sc
    
    // ライセンス消費を抑えるためにセッションログインを行う
    s sc = %session.Login("sem", "", 1)
        
    Quit $$$OK
}

ClassMethod OnPostHTTP()
{
    s %session.EndSession = 1
}

ClassMethod AccountRegistration() As %Status
{
    Set status = $$$OK
    Set result = {}
    Set result.message = ""

    Try {
        Set requestObject = ##Class(%DynamicAbstractObject).%FromJSON(%request.Content)
        
        Set reqName = requestObject.inputName
        Set reqEmail = requestObject.inputEmail
        Set reqPassword = requestObject.inputPassword
        Set reqConfirmPassword = requestObject.inputConfirmPassword

        // Backend validation
        Set validationFlag = 1
        Set validationMessages = ""
        
        If (reqName = "") || '$DATA(reqName) {
            Set status = "ERROR"
            Set validationMessages = validationMessages _ " Name is required."
            Set validationFlag = 0
        }
        If (reqEmail = "") || '$DATA(reqEmail) {
        Set status = "ERROR"
        Set validationMessages = validationMessages _ " Email is required."
        Set validationFlag = 0
        }
        If (reqPassword = "") || '$DATA(reqPassword) {
        Set status = "ERROR"
        Set validationMessages = validationMessages _ " Password is required."
        Set validationFlag = 0
        }
        If (reqConfirmPassword = "") || '$DATA(reqConfirmPassword) {
            Set status = "ERROR"
            Set validationMessages = validationMessages _ " Confirm Password is required."
            Set validationFlag = 0
        }
        If (reqPassword '= reqConfirmPassword) && (validationFlag = 1) {
            Set status = "ERROR"
            Set validationMessages = validationMessages _ " Passwords do not match."
            Set validationFlag = 0
        }
        
        If validationFlag = 0 {
        Set result.message = validationMessages
        Do ##Class(%REST.Impl).%WriteResponse(result)
        Return status
        }

        // Save to database
        Set registrationMessage = ..AccountRegistrationWriteAPI($LISTBUILD(reqName, reqEmail, reqPassword))
        Set result.message = registrationMessage
    }
    Catch ex {
        Set status = ex.AsStatus()
        Set result.message = "Error during registration: " _ ex.DisplayString()
        Do ##Class(%REST.Impl).%WriteResponse(result)
        Return status
    }
    
    Do ##Class(%REST.Impl).%WriteResponse(result)
    Return status
}

ClassMethod AccountRegistrationWriteAPI(dt As %List) As %String
{
    Set inputName = $LISTGET(dt, 1)
    Set inputEmail = $LISTGET(dt, 2)
    Set inputPassword = $LISTGET(dt, 3)

    If (inputName '= "") && (inputEmail '= "") && (inputPassword '= "") {
        // Check if email exists using SQL query
        
        Set sqlQuery = "SELECT ID FROM SEM.tblAccount WHERE Email = ?"
        Set statement = ##class(%SQL.Statement).%New()
        Set status = statement.%Prepare(sqlQuery)
        If $$$ISERR(status) {
            Quit "Error preparing query"
        }
        Set resultSet = statement.%Execute(inputEmail)
        If resultSet.%Next() {
            Quit "Email already registered."
        }
        Else {
            Set newAccount = ##Class(SEM.tblAccount).%New()
            Set newAccount.Email = inputEmail
            
            // FIX 2: Explicitly convert the Name field from UTF8 to IRIS Internal format ("I")
            Set newAccount.Name = $ZCONVERT(inputName, "I", "UTF8")
            
            Set newAccount.Password = inputPassword
            Set status = newAccount.%Save()
            If $$$ISOK(status) {
                Quit "Registration successful."
            }
            Else {
                Quit "Error during registration: " _ $SYSTEM.Status.GetErrorText(status)
            }
        }
    }
    Quit "Invalid input data."
}

ClassMethod AccountLogin() As %Status
{
    Set status = $$$OK
    Set result = {}
    Set result.message = ""

    Try {
        Set requestObject = ##Class(%DynamicAbstractObject).%FromJSON(%request.Content)
        
        Set reqEmail = requestObject.inputEmail
        Set reqPassword = requestObject.inputPassword

        // Backend validation
        Set validationFlag = 1
        Set validationMessages = ""
        
        If (reqEmail = "") || '$DATA(reqEmail) {
            Set status = "ERROR"
            Set validationMessages = validationMessages _ " Email is required."
            Set validationFlag = 0
        }
        If (reqPassword = "") || '$DATA(reqPassword) {
            Set status = "ERROR"
            Set validationMessages = validationMessages _ " Password is required."
            Set validationFlag = 0
        }
        
        If validationFlag = 0 {
            Set result.message = validationMessages
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }

        // Authenticate account
        Set authMessage = ..AccountAuthenticationAPI($LISTBUILD(reqEmail, reqPassword))
        Set result.message = authMessage
    }
    Catch ex {
        Set status = ex.AsStatus()
        Set result.message = "Error during login: " _ ex.DisplayString()
        Do ##Class(%REST.Impl).%WriteResponse(result)
        Return status
    }
    
    Do ##Class(%REST.Impl).%WriteResponse(result)
    Return status
}

ClassMethod AccountAuthenticationAPI(dt As %List) As %String
{
    Set inputEmail = $LISTGET(dt, 1)
    Set inputPassword = $LISTGET(dt, 2)

    If (inputEmail '= "") && (inputPassword '= "") {
        // Check if email exists using SQL query
        
        Set sqlQuery = "SELECT ID, Password FROM SEM.tblAccount WHERE Email = ?"
        Set statement = ##class(%SQL.Statement).%New()
        Set status = statement.%Prepare(sqlQuery)
        If $$$ISERR(status) {
            Quit "Error preparing query"
        }
        
        // NOTE: The CHARSET parameter usually ensures inputEmail and inputPassword are read correctly 
        // from the JSON. No $ZCONVERT is typically needed here for comparison against stored data.
        Set resultSet = statement.%Execute(inputEmail)
        
        If resultSet.%Next() {
            Set storedPassword = resultSet.%Get("Password")
            If storedPassword = inputPassword {
                Return "Authentication successful."
            }Else {
                Return "Invalid password."
            }
        } Else {
            Return "Email is not registered."
        }
    }
    Return "Invalid input data."
}

}
