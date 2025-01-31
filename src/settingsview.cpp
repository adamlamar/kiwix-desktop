#include "settingsview.h"
#include "ui_settings.h"
#include "kiwixapp.h"
#include <kiwix/tools.h>
#include <QMessageBox>
#include <QFileDialog>
SettingsView::SettingsView(QWidget *parent)
    : QWidget(parent)
    , ui(new Ui::Settings)
{
    ui->setupUi(this);
    QFile file(QString::fromUtf8(":/css/_settingsManager.css"));
    file.open(QFile::ReadOnly);
    QString styleSheet = QString(file.readAll());
    ui->widget->setStyleSheet(styleSheet);
    connect(ui->zoomPercentSpinBox, QOverload<int>::of(&QSpinBox::valueChanged), this, &SettingsView::setZoom);
    connect(ui->browseButton, &QPushButton::clicked, this, &SettingsView::browseDownloadDir);
    connect(ui->resetButton, &QPushButton::clicked, this, &SettingsView::resetDownloadDir);
    connect(ui->monitorBrowse, &QPushButton::clicked, this, &SettingsView::browseMonitorDir);
    connect(ui->monitorClear, &QPushButton::clicked, this, &SettingsView::clearMonitorDir);
    connect(KiwixApp::instance()->getSettingsManager(), &SettingsManager::downloadDirChanged, this, &SettingsView::onDownloadDirChanged);
    connect(KiwixApp::instance()->getSettingsManager(), &SettingsManager::monitorDirChanged, this, &SettingsView::onMonitorDirChanged);
    connect(KiwixApp::instance()->getSettingsManager(), &SettingsManager::zoomChanged, this, &SettingsView::onZoomChanged);
    ui->settingsLabel->setText(gt("settings"));
    ui->zoomPercentLabel->setText(gt("zoom-level-setting"));
    ui->downloadDirLabel->setText(gt("download-directory-setting"));
    ui->monitorDirLabel->setText(gt("monitor-directory-setting"));
    ui->resetButton->setText(gt("reset"));
    ui->browseButton->setText(gt("browse"));
    ui->monitorClear->setText(gt("clear"));
    ui->monitorBrowse->setText(gt("browse"));
    ui->monitorHelp->setText("<b>?</b>");
    ui->monitorHelp->setToolTip(gt("monitor-directory-tooltip"));
}

void SettingsView::init(int zoomPercent, const QString &downloadDir, const QString &monitorDir)
{
    ui->zoomPercentSpinBox->setValue(zoomPercent);
    ui->downloadDirPath->setText(downloadDir);
    if (monitorDir == QString()) {
        ui->monitorClear->hide();
    }
    ui->monitorDirPath->setText(monitorDir);
}
bool SettingsView::confirmDialog( QString messageText, QString messageTitle)
{
    QMessageBox msgBox(
        QMessageBox::Question, //Icon
        messageTitle, //Title
        messageText, //Text
        QMessageBox::Ok | QMessageBox::Cancel //Buttons
    );
    msgBox.setDefaultButton(QMessageBox::Ok);

    int ret = msgBox.exec();
    return (ret == QMessageBox::Ok);
}

bool SettingsView::confirmDialogDownloadDir(const QString &dir) {
    auto messageText = gt("download-dir-dialog-msg");
    messageText = messageText.replace("{{DIRECTORY}}", dir);
    return confirmDialog(messageText, gt("download-dir-dialog-title"));
}

bool SettingsView::confirmDialogMonitorDir(const QString &dir) {
    auto messageText = gt("monitor-dir-dialog-msg");
    messageText = messageText.replace("{{DIRECTORY}}", dir);
    auto messageTitle = gt("monitor-dir-dialog-title");
    return confirmDialog(messageText, messageTitle);
}

void SettingsView::resetDownloadDir()
{
    auto dir = QString::fromStdString(kiwix::getDataDirectory());
    const auto &downloadDir = KiwixApp::instance()->getSettingsManager()->getDownloadDir();
    if (dir == downloadDir) {
        return;
    }
    if (confirmDialogDownloadDir(dir)) {
        KiwixApp::instance()->getSettingsManager()->setDownloadDir(dir);
    }
}

void SettingsView::browseDownloadDir()
{
    const auto &downloadDir = KiwixApp::instance()->getSettingsManager()->getDownloadDir();
    QString dir = QFileDialog::getExistingDirectory(KiwixApp::instance()->getMainWindow(),
                                                    gt("browse-directory"),
                                                    downloadDir,
                                                    QFileDialog::ShowDirsOnly);
    if (dir == downloadDir || dir.isEmpty()) {
        return;
    }

    if (confirmDialogDownloadDir(dir)) {
        KiwixApp::instance()->getSettingsManager()->setDownloadDir(dir);
    }
}

void SettingsView::browseMonitorDir()
{
    const auto &monitorDir = KiwixApp::instance()->getSettingsManager()->getMonitorDir();
    QString previousDir;
    if (monitorDir == "") {
        previousDir = KiwixApp::instance()->getSettingsManager()->getDownloadDir();
    } else {
        previousDir = monitorDir;
    }
    QString dir = QFileDialog::getExistingDirectory(KiwixApp::instance()->getMainWindow(),
                                                    gt("browse-directory"),
                                                    previousDir,
                                                    QFileDialog::ShowDirsOnly);
    if (dir == monitorDir || dir.isEmpty()) {
        return;
    }
    if (confirmDialogMonitorDir(dir)) {
        KiwixApp::instance()->setMonitorDir(dir);
    }
}

void SettingsView::clearMonitorDir()
{
    if (confirmDialog(gt("monitor-clear-dir-dialog-msg"), gt("monitor-clear-dir-dialog-title"))) {
        KiwixApp::instance()->setMonitorDir("");
    }
}

void SettingsView::setZoom(int zoomPercent)
{
    qreal zoomFactor = (qreal) zoomPercent/100;
    KiwixApp::instance()->getSettingsManager()->setZoomFactor(zoomFactor);
}

void SettingsView::onDownloadDirChanged(const QString &dir)
{
    ui->downloadDirPath->setText(dir);
}

void SettingsView::onMonitorDirChanged(const QString &dir)
{
    if (dir == "") {
        ui->monitorClear->hide();
    } else {
        ui->monitorClear->show();
    }
    ui->monitorDirPath->setText(dir);
}

void SettingsView::onZoomChanged(qreal zoomFactor)
{
    qreal zoomPercent = zoomFactor * 100;
    ui->zoomPercentSpinBox->setValue(zoomPercent);
}
