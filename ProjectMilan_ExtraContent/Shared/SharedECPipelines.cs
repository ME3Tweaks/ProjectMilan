using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilan_ExtraContent.Shared
{
    internal class SharedECPipelines
    {
        private const string ROOT_FOLDER_NAME = @"ProjectMilan_ExtraContent";
        private static string _ecPipelineRoot;
        public static string ECPipelineRoot
        {
            get
            {
                if (_ecPipelineRoot != null) return _ecPipelineRoot;
                var dir = Directory.GetCurrentDirectory();
                while (Path.GetFileName(dir) != ROOT_FOLDER_NAME)
                {
                    dir = Directory.GetParent(dir).FullName;
                }

                _ecPipelineRoot = dir;
                return _ecPipelineRoot;
            }
        }
    }
}