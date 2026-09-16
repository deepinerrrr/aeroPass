from pathlib import Path
import subprocess, tempfile, socket, time

root=Path(__file__).resolve().parents[1]
files=['Services/QuestionWidgetBridge.swift','Services/QuestionManager.swift','Services/AIService.swift','Services/ChatHistoryStore.swift','Services/KeychainStore.swift','Services/MarkdownToHTMLConverter.swift','Models/StudyModels.swift','Models/CollectionMindMap.swift','Models/ChatMessage.swift','ViewModels/AIChatViewModel.swift']
with tempfile.TemporaryDirectory(prefix='aeropass-feature-checks-') as temp:
    binary=Path(temp)/'features'
    subprocess.run(['xcrun','swiftc','-parse-as-library',*[str(root/'aeropass'/name) for name in files],str(root/'Verification/FeatureSyncTests.swift'),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
    stream=Path(temp)/'stream'
    subprocess.run(['xcrun','swiftc','-parse-as-library',str(root/'aeropass/Services/AIService.swift'),str(root/'aeropass/Services/KeychainStore.swift'),str(root/'Verification/StreamTransportTests.swift'),'-o',str(stream)],check=True)
    server=subprocess.Popen(['python3',str(root/'Verification/sse_fixture_server.py')])
    try:
        for attempt in range(30):
            try:
                with socket.create_connection(('127.0.0.1',18764),timeout=.1): break
            except OSError: time.sleep(.1)
        subprocess.run([str(stream)],check=True)
    finally:
        server.terminate(); server.wait(timeout=5)
    subprocess.run(['python3',str(root/'Verification/run_import_checks.py')],check=True)
