# 11 minutes in qemu

echo '
# cs_CZ.UTF8 UTF-8
# de_DE.UTF8 UTF-8
# en_CA.UTF-8 UTF-8
# en_GB.UTF-8 UTF-8
en_US.UTF-8 UTF-8
# es_ES.UTF8 UTF-8
# fr_CA.UTF8 UTF-8
# fr_FR.UTF8 UTF-8
# it_IT.UTF8 UTF-8
# ja_JP.EUC-JP EUC-JP
# ja_JP.UTF-8 UTF-8
# ko_KR.EUC-KR EUC-KR
# ko_KR.UTF-8 UTF-8
# pl_PL.UTF-8 UTF-8
# pt_BR.UTF-8 UTF-8
# pt_PT.UTF-8 UTF-8
# ru_RU.UTF-8 UTF-8
# tr_TR.UTF-8 UTF-8
# zh_CN.UTF-8 UTF-8
# 
# zh_HK.UTF-8 UTF-8
# zh_SG.UTF-8 UTF-8
# zh_TW.UTF-8 UTF-8

# zh_HK BIG5-HKSCS
# zh_SG GB2312
# zh_SG.GBK GBK
# zh_TW BIG5
# zh_TW.EUC-TW EUC-TW


# zh-Hans
# zh-Hant
' | sudo tee /etc/locale.gen > /dev/null

locales=$(cat /etc/locale.gen | grep -v '#')
Say "Installing Locales: $locales"

time sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales


