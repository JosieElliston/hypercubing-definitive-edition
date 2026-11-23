"""Point a Managed DirectX program at the MDX shim: add bindingRedirects to <exe>.exe.config.

usage: python3 -I mdx-config.py <path to exe.config>

Creates the file, or merges into an existing one (other settings are kept). Why redirect:
wine-mono's GAC holds a partial MDX at 1.0.2902.0, the version the programs reference, and the
GAC beats app-local DLLs. The shim is built at 1.0.2911.0 (shim/Directory.Build.props).

Plain text, not ElementTree: <configuration> must stay outside any namespace and only
<assemblyBinding> may carry xmlns="urn:schemas-microsoft-com:asm.v1". ElementTree hoists
the namespace onto <configuration>, and then the runtime ignores every redirect.
"""
import os
import re
import sys

NAMES = ["Microsoft.DirectX", "Microsoft.DirectX.Direct3D", "Microsoft.DirectX.Direct3DX"]
deps = "".join(
    f'      <dependentAssembly>\n'
    f'        <assemblyIdentity name="{n}" publicKeyToken="31bf3856ad364e35" culture="neutral"/>\n'
    f'        <bindingRedirect oldVersion="1.0.2902.0" newVersion="1.0.2911.0"/>\n'
    f'      </dependentAssembly>\n' for n in NAMES)
binding = f'    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">\n{deps}    </assemblyBinding>\n'

path = sys.argv[1]
text = open(path, encoding="utf-8-sig").read() if os.path.exists(path) else ""
if "Microsoft.DirectX" in text:
    sys.exit(f"{path} already mentions Microsoft.DirectX; merge it by hand")
if not text.strip():
    text = f'<?xml version="1.0" encoding="utf-8"?>\n<configuration>\n  <runtime>\n{binding}  </runtime>\n</configuration>\n'
elif "</runtime>" in text:
    text = text.replace("</runtime>", binding + "  </runtime>", 1)
elif re.search(r"<runtime\s*/>", text):
    text = re.sub(r"<runtime\s*/>", f"<runtime>\n{binding}  </runtime>", text, count=1)
else:
    text = text.replace("</configuration>", f"  <runtime>\n{binding}  </runtime>\n</configuration>", 1)
open(path, "w", encoding="utf-8").write(text)
