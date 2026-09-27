import 'package:kfh_server/kfh_server.dart';
import 'package:test/test.dart';

void main() {
  test('команды делятся по ;, пустые пропускаются', () {
    expect(splitSqlStatements('SELECT 1;\n\n;SELECT 2;  \n'),
        ['SELECT 1', 'SELECT 2']);
  });

  test('последняя команда без ; тоже берётся', () {
    expect(splitSqlStatements('SELECT 1; SELECT 2'), ['SELECT 1', 'SELECT 2']);
  });

  test('; внутри строк и имён — не разделитель', () {
    expect(
      splitSqlStatements("INSERT INTO t VALUES ('a;b', \"c;d\", `e;f`);"),
      ["INSERT INTO t VALUES ('a;b', \"c;d\", `e;f`)"],
    );
  });

  test('экранированные и удвоенные кавычки', () {
    const sql = r"SELECT 'it\'s; ok', 'x''; y'; SELECT 2";
    expect(splitSqlStatements(sql), [r"SELECT 'it\'s; ok', 'x''; y'", 'SELECT 2']);
  });

  test('комментарии убираются, ; в них не считается', () {
    const sql = '-- заголовок; с точкой с запятой\n'
        'CREATE TABLE a (id INT); # ещё; комментарий\n'
        '/* блок; комментария */ SELECT 1;';
    expect(splitSqlStatements(sql), ['CREATE TABLE a (id INT)', 'SELECT 1']);
  });

  test('«--» без пробела — не комментарий (так в MySQL)', () {
    expect(splitSqlStatements('SELECT 5--1;'), ['SELECT 5--1']);
  });

  test('комментарий внутри команды не рвёт её', () {
    expect(
      splitSqlStatements('CREATE TABLE a (\n  x INT, -- поле; важное\n'
          '  y INT\n);'),
      ['CREATE TABLE a (\n  x INT, \n  y INT\n)'],
    );
  });

  test('незакрытые кавычка и комментарий — ошибка', () {
    expect(() => splitSqlStatements("SELECT 'abc;"),
        throwsA(isA<FormatException>()));
    expect(() => splitSqlStatements('SELECT 1 /* abc'),
        throwsA(isA<FormatException>()));
  });

  test('только комментарии — ни одной команды', () {
    expect(splitSqlStatements('-- ничего\n/* нет */\n'), isEmpty);
  });
}
