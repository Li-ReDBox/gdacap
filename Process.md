# Introduction #

Process is an instance of usage of a tool to accomplish a task. It is a ring in data chain. It has **Name**, **Category**, **Comment**, **Tool**, **Input** and **Output**. It is **Input** and **Output** define data flow. Other fields are not used to describe a Process but for attaching it to somewhere and telling who did it. These are: **ProjectAlias**, **Username**.

# Structure of Process #

Process has key-value pairs. Except **input** all other keys cannot be omitted.

  * **Name** gives an identification string to a Process.
  * **ProjectAlias** gives an identification string to a Process.
  * **Username** gives an identification string to a Process.
  * **Category** classifies a Process by a string. This has to be an agreed **Category** otherwise it will fail. **_TODO_**: check from **Category** vocabulary.
  * **Comment** allows user to a comment on a Process.
  * **Tool** describes a tool used in a Process. It is usually software so it has **Name** and **Version** keys. None of them is optional.
  * **Input** provides hashes of input files which can be identified by the system. They should have been in the system. **input** and **output** together provides history of data (e.g. file). Currently, SHA-1 hash is supported.
  * **Output** gives information of new data to a Process. As for files, it needs **OrignalName**, **Hash** and **Type**. Only **Hash** is checked before it is registered. None of these items are optional and they have to be strings.

In Perl format, it looks like this:
```perl

{
"ProjectAlias" => "the name of project with which files associate",
"Username" => "user login name",
"Name" => "The name is meaningful to you",
"Category" => "Agreed process category or type",
"Configuration" => "Command line arguments",
"Comment" => "Describe your process",
"Tool" => {
"Name" => "Your valuable tool",
"Version" => "2"
},
"Input" => ["c9d05e70ef07fcfc210b618705e1b0e9","6ba22c1b40b59e515656b374c74720ee"],
"Output" => [	{
"OriginalName"=> "the name I would like",
"Hash"=> "SHA-1_name1",
"Type"=> "BAM",
"Size":147
},
{
"OriginalName"=> "the name helps me",
"Hash"=> "SHA-1_name2",
"Type"=> "BAM",
"Size":1715
}]
};
```

In JSON format,
```js

{
"ProjectAlias":"the name of project with which files associate",
"Username":"user login name",
"Name":"The name is meaningful to you",
"Category":"Agreed process category or type",
"Configuration":"Command line arguments",
"Comment":"Describe your process",
"Tool":{
"Name":"Your valuable tool",
"Version":"2"
},
"Input":["c9d05e70ef07fcfc210b618705e1b0e9", "6ba22c1b40b59e515656b374c74720ee"],
"Output":[
{
"OriginalName":"the name I would like",
"Hash":"SHA-1_name1",
"Type":"BAM",
"Size":147
},
{
"OriginalName":"the name helps me",
"Hash":"SHA-1_name2",
"Type":"BAM",
"Size":1715
}
]
}
```