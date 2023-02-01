/**************************************************************************
 *
 *  Copyright 2022, Roger Brown
 *
 *  This file is part of Roger Brown's Toolkit.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU Lesser General Public License as published by the
 *  Free Software Foundation, either version 3 of the License, or (at your
 *  option) any later version.
 * 
 *  This program is distributed in the hope that it will be useful, but WITHOUT
 *  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 *  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 *  more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 */

 /* 
  * $Id: dir2wxs.cs 232 2023-01-29 09:46:15Z rhubarb-geek-nz $
  */
 
using System;
using System.Collections.Generic;
using System.IO;
using System.Xml;

namespace dir2wxs
{
    class DirectoryEntry
    {
        public string Id, Name;
        public DirectoryEntry Parent;
        public Dictionary<string,DirectoryEntry> Children=new Dictionary<string,DirectoryEntry>();
        public XmlElement element;
        public string sourceDir;
    }

    class Program
    {
        readonly string WixNamespace = "http://schemas.microsoft.com/wix/2006/wi";
        readonly Dictionary<string,DirectoryEntry> directories = new Dictionary<string,DirectoryEntry>();
        readonly XmlDocument doc = new XmlDocument();
        XmlNamespaceManager nsmgr;
        string destinationDir = "INSTALLDIR";
        string sourceDir = ".";
        XmlElement productComponents;
        XmlElement fileTemplate;
        readonly string[] args;
        static char Slash = Path.DirectorySeparatorChar;

        Program(string [] args)
        {
            this.args = args;
        }

        static void Main(string[] args)
        {
            new Program(args).Main();
        }

        void Main()
        {
            string
                inFile = null,
                outFile = null;

            {
                int i = 0;

                while (i < args.Length)
                {
                    string op = args[i++];

                    switch (op)
                    {
                        case "-i": inFile = args[i++]; break;
                        case "-o": outFile = args[i++]; break;
                        case "-s": sourceDir = args[i++]; break;
                        case "-d": destinationDir = args[i++]; break;
                        default:
                            throw new Exception("unknown option " + op);
                    }
                }
            }

            if (!Directory.Exists(sourceDir))
            {
                throw new Exception($"sourceDir {sourceDir} does not exist");
            }

            if (inFile is null)
            {
                doc.Load(Console.In);
            }
            else
            {
                using FileStream str = new(inFile, FileMode.Open, FileAccess.Read);
                doc.Load(str);
            }

            nsmgr = new XmlNamespaceManager(doc.NameTable);
            nsmgr.AddNamespace("wi", WixNamespace);

            fileTemplate = (XmlElement)GetFiles()[0];
            productComponents = (XmlElement)fileTemplate.ParentNode;

            foreach (XmlNode dir in doc.SelectNodes("/wi:Wix/wi:Fragment/wi:Directory", nsmgr))
            {
                AddDirectory( null, dir);
            }

            RemoveFilesWithoutDirectory();

            RemoveFilesThatDoNotExist();

            AddNewDirectories(directories[destinationDir]);

            foreach (var dir in directories.Values)
            {
                if (dir.sourceDir != null)
                {
                    AddNewFiles(dir);
                }
            }

            if (outFile is null)
            {
                doc.Save(Console.Out);
            }
            else
            {
                using FileStream str = new(outFile, FileMode.Create, FileAccess.Write);
                doc.Save(str);
            }
        }

        void RemoveFilesThatDoNotExist()
        {
            XmlNodeList files = GetFiles();

            foreach (XmlNode v in files)
            {
                XmlElement component = (XmlElement)v;
                
                foreach (XmlNode node in component.ChildNodes)
                {
                    if (node.NodeType == XmlNodeType.Element) 
                    {
                        XmlElement el = (XmlElement)node;

                        if (!File.Exists(el.GetAttribute("Source")))
                        {
                            component.ParentNode.RemoveChild(component);
                            break;
                        }
                    }
                }
            }
        }

        void AddNewFiles(DirectoryEntry parent)
        {
            XmlNodeList existingFiles = GetFiles();

            foreach (string path in Directory.EnumerateFiles(parent.sourceDir))
            {
                string name = BaseName(path);
                string src = $"{parent.sourceDir}{Slash}{name}";
                bool found = false;

                if (src.StartsWith($".{Slash}"))
                {
                    src = src.Substring(2);
                }

                foreach (XmlNode v in existingFiles)
                {
                    XmlElement component = (XmlElement)v;

                    if (parent.Id == component.GetAttribute("Directory"))
                    {
                        XmlNode node = component.FirstChild;

                        while (node != null)
                        {
                            if (node.LocalName == "File")
                            {
                                XmlElement el = (XmlElement)node;

                                string source = el.GetAttribute("Source");

                                if (src == source)
                                {
                                    found = true;
                                    break;
                                }
                            }

                            node = node.NextSibling;
                        }
                    }

                    if (found)
                    {
                        break;
                    }
                }

                if (!found)
                {
                    XmlElement component = (XmlElement)fileTemplate.Clone();
                    XmlNode node = component.FirstChild;

                    while (node.NodeType != XmlNodeType.Element)
                    {
                        node = node.NextSibling;
                    }

                    XmlElement file = (XmlElement)node;

                    file.SetAttribute("Source", src);
                    file.SetAttribute("Id", "F" + Guid.NewGuid().ToString().Replace("-", ""));

                    component.SetAttribute("Id", "C" + Guid.NewGuid().ToString().Replace("-", ""));
                    component.SetAttribute("Directory", parent.Id);

                    productComponents.AppendChild(component);
                }
            }
        }

        void RemoveFilesWithoutDirectory()
        {
            foreach (XmlNode v in GetFiles())
            {
                XmlElement component = (XmlElement)v;
                string dir = component.GetAttribute("Directory");

                if ((dir != null) && !directories.TryGetValue(dir, out DirectoryEntry d))
                {
                    component.ParentNode.RemoveChild(component);
                }
            }
        }

        void AddNewDirectories(DirectoryEntry parent)
        {
            foreach(string path in Directory.EnumerateDirectories(parent.sourceDir))
            {
                string name = BaseName(path);

                if (!parent.Children.TryGetValue(name, out DirectoryEntry subDir))
                {
                    subDir = new DirectoryEntry();
                    subDir.Name = name;
                    subDir.sourceDir = $"{parent.sourceDir}{Slash}{name}";
                    subDir.Parent = parent;
                    parent.Children.Add(name, subDir);

                    int i = 0;

                    while (true)
                    {
                        string id = $"INSTALLDIR{i}";

                        if (!directories.ContainsKey(id))
                        {
                            subDir.Id = id;
                            break;
                        }

                        i++;
                    }

                    subDir.element = doc.CreateElement("Directory", WixNamespace);
                    subDir.element.SetAttribute("Id", subDir.Id);
                    subDir.element.SetAttribute("Name", subDir.Name);

                    parent.element.AppendChild(subDir.element);

                    directories.Add(subDir.Id, subDir);
                }

                AddNewDirectories(subDir);
            }
        }

        DirectoryEntry AddDirectory(DirectoryEntry parent,XmlNode node)
        {
            XmlElement el = (XmlElement)node;
            bool addDir = true;

            DirectoryEntry entry = new DirectoryEntry();

            entry.Id = el.GetAttribute("Id");
            entry.Name = el.GetAttribute("Name");
            entry.Parent = parent;
            entry.element = el;

            if (parent != null)
            {
                if (parent.sourceDir == null)
                {
                    if (entry.Id == destinationDir)
                    {
                        entry.sourceDir = sourceDir;
                    }
                }
                else
                {
                    entry.sourceDir = $"{parent.sourceDir}{Slash}{entry.Name}";

                    addDir = Directory.Exists(entry.sourceDir);

                    if (!addDir)
                    {
                        el.ParentNode.RemoveChild(el);
                    }
                }
            }

            if (addDir)
            {
                directories.Add(entry.Id, entry);

                foreach (XmlNode child in el.ChildNodes)
                {
                    if (child.NodeType == XmlNodeType.Element)
                    {
                        XmlElement cel = (XmlElement)child;

                        if ("Directory" == cel.LocalName)
                        {
                            DirectoryEntry dir = AddDirectory(entry, cel);

                            if (dir != null)
                            {
                                entry.Children.Add(dir.Name, dir);
                            }
                        }
                    }
                }
            }
            else
            {
                entry = null;
            }

            return entry;
        }

        static string BaseName(string s)
        {
            int i = s.LastIndexOf(Slash);

            if (i != -1)
            {
                s = s[(i + 1)..];
            }

            return s;
        }

        XmlNodeList GetFiles()
        {
            return doc.SelectNodes("/wi:Wix/wi:Fragment/wi:ComponentGroup/wi:Component", nsmgr);
        }
    }
}
