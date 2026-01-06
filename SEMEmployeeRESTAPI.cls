Class SEM.SEMEmployeeRESTAPI Extends %CSP.REST
{

// FIX (Kept): Parameter to inform the REST interface the incoming content is UTF-8.

Parameter CHARSET = "UTF8";

/// ライセンス消費対策
Parameter UseSession As Integer = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
        <Route Url="/employees" Method="GET" Call="GetAllEmployees"/>
        <Route Url="/employee/:id" Method="GET" Call="GetEmployeeById"/>
        <Route Url="/employee" Method="POST" Call="CreateEmployee"/>
        <Route Url="/employee/:id" Method="PUT" Call="UpdateEmployee"/>
        <Route Url="/employee/:id" Method="DELETE" Call="DeleteEmployee"/>
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

/// Get all employees (non-deleted only)
ClassMethod GetAllEmployees() As %Status
{
    Set status = $$$OK
    Set result = {}
    Set result.employees = []
    
    Try {
        Set sqlQuery = "SELECT ID, EmployeeId, Name, KanaName, Sex, PostCode, Address, PhoneNumber, Email, Department, RetireFlg, upDateTime FROM SEM.tblEmployee WHERE deleteFlg = 0 ORDER BY upDateTime DESC"
        Set statement = ##class(%SQL.Statement).%New()
        Set status = statement.%Prepare(sqlQuery)
        
        If $$$ISERR(status) {
            Set result.message = "Error preparing query"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        Set resultSet = statement.%Execute()
        
        While resultSet.%Next() {
            Set employee = {}
            Set employee.id = resultSet.%Get("ID")
            Set employee.EmployeeId = resultSet.%Get("EmployeeId")
            Set employee.Name = resultSet.%Get("Name")
            Set employee.KanaName = resultSet.%Get("KanaName")
            Set employee.Sex = resultSet.%Get("Sex")
            Set employee.PostCode = resultSet.%Get("PostCode")
            Set employee.Address = resultSet.%Get("Address")
            Set employee.PhoneNumber = resultSet.%Get("PhoneNumber")
            Set employee.Email = resultSet.%Get("Email")
            Set employee.Department = resultSet.%Get("Department")
            Set employee.RetireFlg = resultSet.%Get("RetireFlg")
            Set employee.upDateTime = resultSet.%Get("upDateTime")
            
            Do result.employees.%Push(employee)
        }
        
        Set result.message = "Employees retrieved successfully"
    }
    Catch ex {
        Set status = ex.AsStatus()
        Set result.message = "Error retrieving employees: " _ ex.DisplayString()
    }
    
    // NOTE: The JSON response generation handles conversion for output automatically.
    Do ##Class(%REST.Impl).%WriteResponse(result)
    Return status
}

/// Get employee by ID
ClassMethod GetEmployeeById(id As %String) As %Status
{
    Set status = $$$OK
    Set result = {}
    
    Try {
        Set employee = ##class(SEM.tblEmployee).%OpenId(id)
        
        If '$IsObject(employee) {
            Set result.message = "Employee not found"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        If employee.deleteFlg = 1 {
            Set result.message = "Employee has been deleted"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        Set result.id = employee.%Id()
        Set result.employeeId = employee.EmployeeId
        Set result.name = employee.Name
        Set result.kanaName = employee.KanaName
        Set result.sex = employee.Sex
        Set result.postCode = employee.PostCode
        Set result.address = employee.Address
        Set result.phoneNumber = employee.PhoneNumber
        Set result.email = employee.Email
        Set result.department = employee.Department
        Set result.retireFlg = employee.RetireFlg
        Set result.upDateTime = employee.upDateTime
        Set result.message = "Employee retrieved successfully"
    }
    Catch ex {
        Set status = ex.AsStatus()
        Set result.message = "Error retrieving employee: " _ ex.DisplayString()
    }
    
    Do ##Class(%REST.Impl).%WriteResponse(result)
    Return status
}

/// Helper method to get value from dynamic object or return default
ClassMethod GetValueOrDefault(obj As %DynamicAbstractObject, key As %String, default As %String = "") As %String
{
    If obj.%IsDefined(key) {
        Return obj.%Get(key)
    }
    Return default
}

/// NEW: Auto-generate next Employee ID
/// Returns the next available Employee ID (MAX + 1)
ClassMethod GetNextEmployeeId() As %String
{
    Set nextId = "00001"  // Default for first employee
    
    Try {
        // Query MAX EmployeeId (using INDEX for performance)
        Set sqlQuery = "SELECT MAX(EmployeeId) AS MaxId FROM SEM.tblEmployee WHERE deleteFlg = 0"
        Set statement = ##class(%SQL.Statement).%New()
        Set status = statement.%Prepare(sqlQuery)
        
        If $$$ISOK(status) {
            Set resultSet = statement.%Execute()
            
            If resultSet.%Next() {
                Set maxId = resultSet.%Get("MaxId")
                
                // If maxId exists and is valid
                If (maxId '= "") && ($IsValidNum(maxId)) {
                    // Convert to number, add 1, format as 5 digits
                    Set nextIdNum = maxId + 1
                    Set nextId = $Justify(nextIdNum, 5)  // Pad with zeros (e.g., "00042")
                    Set nextId = $Translate(nextId, " ", "0")  // Replace spaces with zeros
                }
            }
        }
    }
    Catch ex {
        // If any error, return default "00001"
        Set nextId = "00001"
    }
    
    Return nextId
}

/// Create new employee
ClassMethod CreateEmployee() As %Status
{
    Set status = $$$OK
    Set result = {}
    
    Try {
        Set requestObject = ##Class(%DynamicAbstractObject).%FromJSON(%request.Content)
        
        // AUTO-GENERATE Employee ID (NEW FEATURE)
        Set autoGeneratedId = ..GetNextEmployeeId()
        
        // Validation (omitted for brevity, assume valid structure)
        Set validationFlag = 1
        Set validationMessages = ""
        
        // Employee ID is now auto-generated, so we don't check if user provided it
        // But if frontend somehow sends it, we IGNORE it and use auto-generated one
        
        If (..GetValueOrDefault(requestObject, "name") = "") {
            Set validationMessages = validationMessages _ " Name is required."
            Set validationFlag = 0
        }
        
        If validationFlag = 0 {
            Set result.message = validationMessages
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        // Check if auto-generated EmployeeId already exists (edge case protection)
        Set sqlQuery = "SELECT ID FROM SEM.tblEmployee WHERE EmployeeId = ? AND deleteFlg = 0"
        Set statement = ##class(%SQL.Statement).%New()
        Set status = statement.%Prepare(sqlQuery)
        
        If $$$ISERR(status) {
            Set result.message = "Error preparing query"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        Set resultSet = statement.%Execute(autoGeneratedId)
        If resultSet.%Next() {
            // This should NEVER happen if MAX() logic is correct, but safety check
            Set result.message = "Generated Employee ID already exists (system error)"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        // Create new employee
        Set newEmployee = ##Class(SEM.tblEmployee).%New()
        
        // --- FIX: Use AUTO-GENERATED Employee ID ---
        Set newEmployee.EmployeeId = autoGeneratedId
        
        // --- FIX: Explicitly convert incoming UTF-8 strings to Internal format ---
        Set newEmployee.Name = $ZCONVERT(requestObject.name, "I", "UTF8")
        Set newEmployee.KanaName = $ZCONVERT(..GetValueOrDefault(requestObject, "kanaName", ""), "I", "UTF8")
        Set newEmployee.Sex = ..GetValueOrDefault(requestObject, "sex", 0) // Numeric
        Set newEmployee.PostCode = $ZCONVERT(..GetValueOrDefault(requestObject, "postCode", ""), "I", "UTF8")
        Set newEmployee.Address = $ZCONVERT(..GetValueOrDefault(requestObject, "address", ""), "I", "UTF8")
        Set newEmployee.PhoneNumber = $ZCONVERT(..GetValueOrDefault(requestObject, "phoneNumber", ""), "I", "UTF8")
        Set newEmployee.Email = $ZCONVERT(..GetValueOrDefault(requestObject, "email", ""), "I", "UTF8")
        Set newEmployee.Department = $ZCONVERT(..GetValueOrDefault(requestObject, "department", ""), "I", "UTF8")
        Set newEmployee.RetireFlg = ..GetValueOrDefault(requestObject, "retireFlg", 0) // Numeric
        // --- END FIX ---
        
        Set newEmployee.deleteFlg = 0
        Set newEmployee.upDateTime = $ZDATETIME($HOROLOG, 3)
        
        Set status = newEmployee.%Save()
        
        If $$$ISOK(status) {
            Set result.message = "Employee created successfully"
            Set result.id = newEmployee.%Id()
            Set result.employeeId = autoGeneratedId  // Return generated ID to frontend
        } Else {
            Set result.message = "Error creating employee: " _ $SYSTEM.Status.GetErrorText(status)
        }
    }
    Catch ex {
        Set status = ex.AsStatus()
        Set result.message = "Error creating employee: " _ ex.DisplayString()
    }
    
    Do ##Class(%REST.Impl).%WriteResponse(result)
    Return status
}

/// Update employee
ClassMethod UpdateEmployee(id As %String) As %Status
{
    Set status = $$$OK
    Set result = {}
    
    Try {
        Set requestObject = ##Class(%DynamicAbstractObject).%FromJSON(%request.Content)
        
        Set employee = ##class(SEM.tblEmployee).%OpenId(id)
        
        If '$IsObject(employee) {
            Set result.message = "Employee not found"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        If employee.deleteFlg = 1 {
            Set result.message = "Cannot update deleted employee"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        // Validation (omitted for brevity)
        Set validationFlag = 1
        Set validationMessages = ""
        
        If (..GetValueOrDefault(requestObject, "name") = "") {
            Set validationMessages = validationMessages _ " Name is required."
            Set validationFlag = 0
        }
        
        If validationFlag = 0 {
            Set result.message = validationMessages
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        // --- IMPORTANT: Employee ID is IMMUTABLE (cannot be changed) ---
        // We do NOT update EmployeeId even if frontend sends it
        // DO NOT INCLUDE: Set employee.EmployeeId = requestObject.employeeId
        
        // Update employee (excluding EmployeeId)
        // --- FIX: Explicitly convert incoming UTF-8 strings to Internal format ---
        Set employee.Name = $ZCONVERT(requestObject.name, "I", "UTF8")
        
        // Only update optional fields if provided
        If requestObject.%IsDefined("kanaName") {
            Set employee.KanaName = $ZCONVERT(requestObject.kanaName, "I", "UTF8")
        }
        If requestObject.%IsDefined("sex") {
            Set employee.Sex = requestObject.sex
        }
        If requestObject.%IsDefined("postCode") {
            Set employee.PostCode = $ZCONVERT(requestObject.postCode, "I", "UTF8")
        }
        If requestObject.%IsDefined("address") {
            Set employee.Address = $ZCONVERT(requestObject.address, "I", "UTF8")
        }
        If requestObject.%IsDefined("phoneNumber") {
            Set employee.PhoneNumber = $ZCONVERT(requestObject.phoneNumber, "I", "UTF8")
        }
        If requestObject.%IsDefined("email") {
            Set employee.Email = $ZCONVERT(requestObject.email, "I", "UTF8")
        }
        If requestObject.%IsDefined("department") {
            Set employee.Department = $ZCONVERT(requestObject.department, "I", "UTF8")
        }
        If requestObject.%IsDefined("retireFlg") {
            Set employee.RetireFlg = requestObject.retireFlg
        }
        If requestObject.%IsDefined("deleteFlg") {
            Set employee.deleteFlg = requestObject.deleteFlg
        }
        // --- END FIX ---

        Set employee.upDateTime = $ZDATETIME($HOROLOG, 3)
        
        Set status = employee.%Save()
        
        If $$$ISOK(status) {
            Set result.message = "Employee updated successfully"
        } Else {
            Set result.message = "Error updating employee: " _ $SYSTEM.Status.GetErrorText(status)
        }
    }
    Catch ex {
        Set status = ex.AsStatus()
        Set result.message = "Error updating employee: " _ ex.DisplayString()
    }
    
    Do ##Class(%REST.Impl).%WriteResponse(result)
    Return status
}

/// Soft delete employee (set deleteFlg = 1)
ClassMethod DeleteEmployee(id As %String) As %Status
{
    Set status = $$$OK
    Set result = {}
    
    Try {
        Set employee = ##class(SEM.tblEmployee).%OpenId(id)
        
        If '$IsObject(employee) {
            Set result.message = "Employee not found"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        If employee.deleteFlg = 1 {
            Set result.message = "Employee already deleted"
            Do ##Class(%REST.Impl).%WriteResponse(result)
            Return status
        }
        
        // Soft delete
        Set employee.deleteFlg = 1
        Set employee.upDateTime = $ZDATETIME($HOROLOG, 3)
        
        Set status = employee.%Save()
        
        If $$$ISOK(status) {
            Set result.message = "Employee deleted successfully"
        } Else {
            Set result.message = "Error deleting employee: " _ $SYSTEM.Status.GetErrorText(status)
        }
    }
    Catch ex {
        Set status = ex.AsStatus()
        Set result.message = "Error deleting employee: " _ ex.DisplayString()
    }
    
    Do ##Class(%REST.Impl).%WriteResponse(result)
    Return status
}

}
