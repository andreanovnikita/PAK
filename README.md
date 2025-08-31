Программно-аппаратный комплекс состоит из следующих частей:

1.	perfectcrypt – данный компонент позволяет создать двойное дно - специальный «смертельный» пароль, который уничтожит все данные на сервере при его вводе.<br>
Ссылка на исходный код:  <br>https://github.com/andreanovnikita/perfectcrypt

2.	Командный центр – данный компонент позволяет разблокировать сервер удалённо, с использованием отечественных алгоритмов шифрования.<br>
Ссылки на исходный код:

https://github.com/andreanovnikita/PAK/tree/main/SSHLuks<br>
https://github.com/andreanovnikita/PAK/blob/main/wg-management.sh<br>
https://github.com/andreanovnikita/PAK/blob/main/wg-install.sh

4.	udev-control – данный компонент позволяет уничтожить данные уже после загрузки сервера, например при неожиданно возникшей угрозе.<br>
Ссылка на исходный код: https://github.com/andreanovnikita/PAK/blob/main/erase.sh
