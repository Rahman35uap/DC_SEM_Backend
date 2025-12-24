Class SEM.tblEmployee Extends %Persistent
{

Property EmployeeId As %String(MAXLEN = 5) [ Required ];

Property Name As %String(MAXLEN = 64) [ Required ];

Property KanaName As %String(MAXLEN = 64);

Property Sex As %Integer;

Property PostCode As %String(MAXLEN = 8);

Property Address As %String(MAXLEN = 1024);

Property PhoneNumber As %String(MAXLEN = 13);

Property Department As %String(MAXLEN = 64);

Property RetireFlg As %Boolean [ Required ];

Property deleteFlg As %Boolean [ Required ];

Property upDateTime As %DateTime [ Required ];

Storage Default
{
<Data name="tblEmployeeDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ID</Value>
</Value>
<Value name="3">
<Value>EmployeeId</Value>
</Value>
<Value name="4">
<Value>Name</Value>
</Value>
<Value name="5">
<Value>KanaName</Value>
</Value>
<Value name="6">
<Value>Sex</Value>
</Value>
<Value name="7">
<Value>PostCode</Value>
</Value>
<Value name="8">
<Value>Address</Value>
</Value>
<Value name="9">
<Value>PhoneNumber</Value>
</Value>
<Value name="10">
<Value>Department</Value>
</Value>
<Value name="11">
<Value>RetireFlg</Value>
</Value>
<Value name="12">
<Value>deleteFlg</Value>
</Value>
<Value name="13">
<Value>upDateTime</Value>
</Value>
</Data>
<DataLocation>^SEM.tblEmployeeD</DataLocation>
<DefaultData>tblEmployeeDefaultData</DefaultData>
<IdLocation>^SEM.tblEmployeeD</IdLocation>
<IndexLocation>^SEM.tblEmployeeI</IndexLocation>
<StreamLocation>^SEM.tblEmployeeS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
