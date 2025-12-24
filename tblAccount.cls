Class SEM.tblAccount Extends %Persistent
{

Property Email As %String(MAXLEN = 32) [ Required ];

Property Password As %String(MAXLEN = 32);

Property Name As %String(MAXLEN = 64);

Storage Default
{
<Data name="tblAccountDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ID</Value>
</Value>
<Value name="3">
<Value>Email</Value>
</Value>
<Value name="4">
<Value>Password</Value>
</Value>
<Value name="5">
<Value>Name</Value>
</Value>
</Data>
<DataLocation>^SEM.tblAccountD</DataLocation>
<DefaultData>tblAccountDefaultData</DefaultData>
<IdLocation>^SEM.tblAccountD</IdLocation>
<IndexLocation>^SEM.tblAccountI</IndexLocation>
<StreamLocation>^SEM.tblAccountS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
