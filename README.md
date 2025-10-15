# Mule Env

In diesem Verzeichnis befindet sich die komplette Entwicklungsumgebung für MuleSoft.
Das behinhaltet zum einen die aktuell unterstützte Anypoint Studio Version. Zum anderen ist hier ein vorkonfiguriertes Maven enthalten.

## Starten
Zum Starten des Studios, der angepassten einer Kommandozeile sowie der spezifischen Powershell müssen die hier enthaltenen Startskripte verwendet werden.
- Start-Studio.cmd: wird verwendet, um das Studio zu starten
- Start-Console.cmd: darüber kann eine Kommandozeile geöffnet werden, die alle Pfade und Umgebungsvariablen richtig gesetzt hat
- Start-MuleShell.cmd: Startet eine Powershell mit den richtigen Umgebungsvariablen und einigen weiteren Variablen für die Mule Umgebung

## Admin

### MuleShell
Startet man die Mule-Powershell, stehen erweiterte Funktionen zur Verfügung, die es ermöglichen, manuell z.B. eine Installation mit einem neuen Anypoint-Studio-ZIP zu starten.

#### Übersicht der wichtigsten Funktionen
- Install-MuleEnv: Installiert d.h. erzeugt eine neue Mule-Umgebung, d.h. Studio, Workspace, Maven und Startskripte
- Clear-MuleEnv: löscht alle Dateien, die nicht für die Installation benötigt werden (entspricht Reset auf Installations-Package)

Darüber sind die folgenden Cmdlets nützlich, um bei einer bestehenden Installation die Defaults wieder anzuwenden und ggf. fehlende Patches erneut auszuführen (z.B. das Hinzufügen des Webgateway-Zertifikats zur cacerts im Studio)
- Update-Studio: Überschreibt die Einstellungen vom Studio mit den Defaults und patched ggf. vorhandene Dateien
- Update-Workspace: Überschreibt die Einstellungen im Workspace mit den Defaults und patched ggf. vorhandene Dateien
- Update-Maven: Überschreibt die Einstellungen von Maven mit den Defaults und patched ggf. vorhandene Dateien

#### Erstellen von Paketen mit Installationsdateien oder der kompletten MuleEnv
Zum Erzeugen eines ZIPs mit entweder nur den zur Installation benötigten Dateien oder einer komplett initialisierten Mule-Entwicklungsumgebung (nach dem Ausführen von Install-MuleEnv), können zwei Cmdlets benutzt werden:
- Build-MuleEnvSetupPackage: Erzeugt ein ZIP, dass alle Skripte und Dateien enthält, um eine neue Entwicklungsumgebung daraus zu erstellen.
- Build-MuleEnvPackage: Erzeugt ein ZIP nachdem eine vollständige Entwicklungsumgebung erzeugt wurde, z.B. um das ZIP danach für die Software-Verteilung nutzen zu können.

## Ideen:
- Properties (YAML) für Parameter wie Region, Default JDK etc.
- Möglichkeit JDK zu wechseln

---

