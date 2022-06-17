import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web_socket_channel/io.dart';

class Task {
  final int? id;
  final String? taskName;
  final bool? isCompleted;
  Task({this.id, this.taskName, this.isCompleted});
}

class TodoListModel extends ChangeNotifier {
  List<Task> todos = [];
  bool isLoading = true;
  int? taskCount;
  late final String _rpcUrl = dotenv.env['RPC_URL']!;
  late final String _wsUrl = dotenv.env['WEBSOCKET_URL']!;
  late final String _privateKey = dotenv.env['PRIVATE_KEY']!;
  late final int _chainId = int.parse(dotenv.env['CHAIN_ID']!);

  late final _client = Web3Client(_rpcUrl, Client(), socketConnector: () {
    return IOWebSocketChannel.connect(_wsUrl).cast<String>();
  });
  late final _credentials = EthPrivateKey.fromHex(_privateKey);
  late final address = _credentials.address;

  String? _abiCode;

  EthereumAddress? _contractAddress;
  DeployedContract? _contract;

  ContractFunction? _taskCount;
  ContractFunction? _todos;
  ContractFunction? _createTask;
  ContractFunction? _updateTask;
  ContractFunction? _deleteTask;
  ContractFunction? _toggleComplete;

  TodoListModel() {
    init();
  }

  Future<void> init() async {
    await getAbi();
    await getDeployedContract();
  }

  //スマートコントラクトの`ABI`を取得し、デプロイされたコントラクトのアドレスを取り出す。
  Future<void> getAbi() async {
    String abiStringFile = await rootBundle.loadString("smartcontract/TodoContract.json");
    var jsonAbi = jsonDecode(abiStringFile);
    _abiCode = jsonEncode(jsonAbi["abi"]);
    _contractAddress = EthereumAddress.fromHex(jsonAbi["networks"]["$_chainId"]["address"]);
  }

  //`_abiCode`と`_contractAddress`を使用して、スマートコントラクトのインスタンスを作成する。
  Future<void> getDeployedContract() async {
    _contract = DeployedContract(ContractAbi.fromJson(_abiCode!, "TodoList"), _contractAddress!);
    _taskCount = _contract!.function("taskCount");
    _updateTask = _contract!.function("updateTask");
    _createTask = _contract!.function("createTask");
    _deleteTask = _contract!.function("deleteTask");
    _toggleComplete = _contract!.function("toggleComplete");
    _todos = _contract!.function("todos");
    await getTodos();
  }

  getTodos() async {
    isLoading = true;
    notifyListeners();
    List totalTaskList = await _client.call(
      sender: _contractAddress,
      contract: _contract!,
      function: _taskCount!,
      params: [],
    );

    BigInt totalTask = totalTaskList[0];
    taskCount = totalTask.toInt();
    todos.clear();
    for (var i = 0; i < totalTask.toInt(); i++) {
      var temp =
          await _client.call(contract: _contract!, function: _todos!, params: [BigInt.from(i)]);
      if (temp[1] != "") {
        todos.add(Task(id: (temp[0] as BigInt).toInt(), taskName: temp[1], isCompleted: temp[2]));
      }
    }
    isLoading = false;
    todos = todos.reversed.toList();
    notifyListeners();
  }

  //1.to-doを作成する機能
  addTask(String taskNameData) async {
    isLoading = true;
    notifyListeners();
    final result = await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract!,
        function: _createTask!,
        parameters: [taskNameData],
        // gasPrice: EtherAmount.inWei(BigInt.from(160000)),
      ),
      chainId: _chainId,
    );
    print(result);
    await getTodos();
  }

  //2.to-doを更新する機能
  updateTask(int id, String taskNameData) async {
    isLoading = true;
    notifyListeners();
    final result = await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract!,
        function: _updateTask!,
        parameters: [BigInt.from(id), taskNameData],
        // gasPrice: EtherAmount.inWei(BigInt.from(160000)),
      ),
      chainId: _chainId,
    );
    print(result);
    await getTodos();
  }

  //3.to-doの完了・未完了を切り替える機能
  toggleComplete(int id) async {
    isLoading = true;
    notifyListeners();
    final result = await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract!,
        function: _toggleComplete!,
        parameters: [BigInt.from(id)],
        // gasPrice: EtherAmount.inWei(BigInt.from(160000)),
      ),
      chainId: _chainId,
    );
    print(result);
    await getTodos();
  }

  //4.to-doを削除する機能
  deleteTask(int id) async {
    isLoading = true;
    notifyListeners();
    final result = await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract!,
        function: _deleteTask!,
        parameters: [BigInt.from(id)],
        // gasPrice: EtherAmount.inWei(BigInt.from(160000)),
      ),
      chainId: 80001,
    );
    print(result);
    await getTodos();
  }
}
