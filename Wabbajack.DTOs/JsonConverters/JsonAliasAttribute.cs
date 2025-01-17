using System;

namespace Wabbajack.DTOs.JsonConverters;

[AttributeUsage(AttributeTargets.Class, AllowMultiple = true, Inherited = false)]
public class JsonAliasAttribute : Attribute
{
    public JsonAliasAttribute(string alias)
    {
        Alias = alias;
    }

    public string Alias { get; }
}