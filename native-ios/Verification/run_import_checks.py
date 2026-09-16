from pathlib import Path
import tempfile, shutil, zipfile, xml.sax.saxutils as xml, subprocess

project = Path(__file__).resolve().parents[1]
root = Path(tempfile.mkdtemp(prefix='aeropass-import-checks-'))
sources = root/'Sources'/'ImportChecks'; sources.mkdir(parents=True)
files = ['Services/QuestionWidgetBridge.swift','Services/ExcelQuestionImporter.swift','Services/QuestionManager.swift','Services/AIService.swift','Services/ChatHistoryStore.swift','Services/KeychainStore.swift','Models/StudyModels.swift','Models/CollectionMindMap.swift','Models/ChatMessage.swift']
for name in files: shutil.copy2(project/'aeropass'/name, sources/Path(name).name)
shutil.copy2(project/'Verification/ImportValidationTests.swift',sources/'ImportValidationTests.swift')
(root/'Package.swift').write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ImportChecks", platforms: [.macOS(.v14)], dependencies: [.package(url: "https://github.com/CoreOffice/CoreXLSX.git", exact: "0.14.2")], targets: [.executableTarget(name: "ImportChecks", dependencies: ["CoreXLSX"])])
''')
fixtures=root/'fixtures';fixtures.mkdir()
def workbook(name, rows):
    strings=[]
    for row in rows:
        for value in row:
            if value not in strings: strings.append(value)
    sheet='<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
    for i,row in enumerate(rows,1):
        sheet+=f'<row r="{i}">'+''.join(f'<c r="{chr(65+j)}{i}" t="s"><v>{strings.index(value)}</v></c>' for j,value in enumerate(row))+'</row>'
    sheet+='</sheetData></worksheet>'
    with zipfile.ZipFile(fixtures/(name+'.xlsx'),'w') as z:
        z.writestr('[Content_Types].xml','<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/></Types>')
        z.writestr('_rels/.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        z.writestr('xl/workbook.xml','<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="气象" sheetId="1" r:id="rId1"/></sheets></workbook>')
        z.writestr('xl/_rels/workbook.xml.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/></Relationships>')
        z.writestr('xl/sharedStrings.xml','<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="'+str(len(strings))+'" uniqueCount="'+str(len(strings))+'">'+''.join('<si><t>'+xml.escape(v)+'</t></si>' for v in strings)+'</sst>')
        z.writestr('xl/worksheets/sheet1.xml',sheet)
header=['题干','答案','题号','A','B','C','D']
valid=['海平面温度？','C','101','0℃','10℃','15℃','25℃']
judge=['地球自转方向为自西向东。','正确','102','正确','错误','','']
workbook('valid',[header,valid,judge])
workbook('missing',[header,valid,['','A','102','正确','错误']])
workbook('duplicate',[header,valid,valid])
workbook('nooption',[header,['温度？','C','101','0℃','10℃','','']])
workbook('badanswer',[header,['温度？','Z','101','0℃','10℃','15℃','25℃']])
try:
    result=subprocess.run(['swift','run','--package-path',str(root),'ImportChecks',str(fixtures)])
    raise SystemExit(result.returncode)
finally: shutil.rmtree(root)
