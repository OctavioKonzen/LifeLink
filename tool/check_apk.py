"""Confere o APK antes de publicar: as funções que o Dart chama pelo NOME (via
JNI) precisam estar com o nome original. Se o R8 renomear algo (por exemplo
kotlin.coroutines.Continuation), o app fecha ao abrir com NoSuchMethodError,
como aconteceu nas versões 1.0.1 e 1.0.2.

Uso: python3 tool/check_apk.py caminho/do/app.apk  (precisa do androguard)
"""

import sys
import zipfile

from androguard.core.dex import DEX

# Classe → função → assinatura que o shared_preferences_android procura.
EXPECTED = {
    'Lio/flutter/plugins/sharedpreferences/SharedPreferencesApiRegistrar;': {
        'getAll': '(Ljava/lang/String; Ljava/util/List; Lkotlin/coroutines/Continuation;)Ljava/lang/Object;',
    },
}


def main(path):
    found = {}
    with zipfile.ZipFile(path) as apk:
        for name in apk.namelist():
            if not (name.startswith('classes') and name.endswith('.dex')):
                continue
            for cls in DEX(apk.read(name)).get_classes():
                wanted = EXPECTED.get(cls.get_name())
                if not wanted:
                    continue
                for method in cls.get_methods():
                    if method.get_name() in wanted:
                        found[(cls.get_name(), method.get_name())] = method.get_descriptor()
    ok = True
    for cls, methods in EXPECTED.items():
        for method, descriptor in methods.items():
            got = found.get((cls, method))
            if got != descriptor:
                print(f'ERRO: {cls}{method} está como {got!r}, o Dart procura {descriptor!r}.')
                ok = False
    print('APK OK: nomes do código preservados.' if ok else 'O app fecharia ao abrir.')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
