var Web3 = require("web3");
var SolidityEvent = require("web3/lib/web3/event.js");

(function() {
  // Planned for future features, logging, etc.
  function Provider(provider) {
    this.provider = provider;
  }

  Provider.prototype.send = function() {
    this.provider.send.apply(this.provider, arguments);
  };

  Provider.prototype.sendAsync = function() {
    this.provider.sendAsync.apply(this.provider, arguments);
  };

  var BigNumber = (new Web3()).toBigNumber(0).constructor;

  var Utils = {
    is_object: function(val) {
      return typeof val == "object" && !Array.isArray(val);
    },
    is_big_number: function(val) {
      if (typeof val != "object") return false;

      // Instanceof won't work because we have multiple versions of Web3.
      try {
        new BigNumber(val);
        return true;
      } catch (e) {
        return false;
      }
    },
    merge: function() {
      var merged = {};
      var args = Array.prototype.slice.call(arguments);

      for (var i = 0; i < args.length; i++) {
        var object = args[i];
        var keys = Object.keys(object);
        for (var j = 0; j < keys.length; j++) {
          var key = keys[j];
          var value = object[key];
          merged[key] = value;
        }
      }

      return merged;
    },
    promisifyFunction: function(fn, C) {
      var self = this;
      return function() {
        var instance = this;

        var args = Array.prototype.slice.call(arguments);
        var tx_params = {};
        var last_arg = args[args.length - 1];

        // It's only tx_params if it's an object and not a BigNumber.
        if (Utils.is_object(last_arg) && !Utils.is_big_number(last_arg)) {
          tx_params = args.pop();
        }

        tx_params = Utils.merge(C.class_defaults, tx_params);

        return new Promise(function(accept, reject) {
          var callback = function(error, result) {
            if (error != null) {
              reject(error);
            } else {
              accept(result);
            }
          };
          args.push(tx_params, callback);
          fn.apply(instance.contract, args);
        });
      };
    },
    synchronizeFunction: function(fn, instance, C) {
      var self = this;
      return function() {
        var args = Array.prototype.slice.call(arguments);
        var tx_params = {};
        var last_arg = args[args.length - 1];

        // It's only tx_params if it's an object and not a BigNumber.
        if (Utils.is_object(last_arg) && !Utils.is_big_number(last_arg)) {
          tx_params = args.pop();
        }

        tx_params = Utils.merge(C.class_defaults, tx_params);

        return new Promise(function(accept, reject) {

          var decodeLogs = function(logs) {
            return logs.map(function(log) {
              var logABI = C.events[log.topics[0]];

              if (logABI == null) {
                return null;
              }

              var decoder = new SolidityEvent(null, logABI, instance.address);
              return decoder.decode(log);
            }).filter(function(log) {
              return log != null;
            });
          };

          var callback = function(error, tx) {
            if (error != null) {
              reject(error);
              return;
            }

            var timeout = C.synchronization_timeout || 240000;
            var start = new Date().getTime();

            var make_attempt = function() {
              C.web3.eth.getTransactionReceipt(tx, function(err, receipt) {
                if (err) return reject(err);

                if (receipt != null) {
                  // If they've opted into next gen, return more information.
                  if (C.next_gen == true) {
                    return accept({
                      tx: tx,
                      receipt: receipt,
                      logs: decodeLogs(receipt.logs)
                    });
                  } else {
                    return accept(tx);
                  }
                }

                if (timeout > 0 && new Date().getTime() - start > timeout) {
                  return reject(new Error("Transaction " + tx + " wasn't processed in " + (timeout / 1000) + " seconds!"));
                }

                setTimeout(make_attempt, 1000);
              });
            };

            make_attempt();
          };

          args.push(tx_params, callback);
          fn.apply(self, args);
        });
      };
    }
  };

  function instantiate(instance, contract) {
    instance.contract = contract;
    var constructor = instance.constructor;

    // Provision our functions.
    for (var i = 0; i < instance.abi.length; i++) {
      var item = instance.abi[i];
      if (item.type == "function") {
        if (item.constant == true) {
          instance[item.name] = Utils.promisifyFunction(contract[item.name], constructor);
        } else {
          instance[item.name] = Utils.synchronizeFunction(contract[item.name], instance, constructor);
        }

        instance[item.name].call = Utils.promisifyFunction(contract[item.name].call, constructor);
        instance[item.name].sendTransaction = Utils.promisifyFunction(contract[item.name].sendTransaction, constructor);
        instance[item.name].request = contract[item.name].request;
        instance[item.name].estimateGas = Utils.promisifyFunction(contract[item.name].estimateGas, constructor);
      }

      if (item.type == "event") {
        instance[item.name] = contract[item.name];
      }
    }

    instance.allEvents = contract.allEvents;
    instance.address = contract.address;
    instance.transactionHash = contract.transactionHash;
  };

  // Use inheritance to create a clone of this contract,
  // and copy over contract's static functions.
  function mutate(fn) {
    var temp = function Clone() { return fn.apply(this, arguments); };

    Object.keys(fn).forEach(function(key) {
      temp[key] = fn[key];
    });

    temp.prototype = Object.create(fn.prototype);
    bootstrap(temp);
    return temp;
  };

  function bootstrap(fn) {
    fn.web3 = new Web3();
    fn.class_defaults  = fn.prototype.defaults || {};

    // Set the network iniitally to make default data available and re-use code.
    // Then remove the saved network id so the network will be auto-detected on first use.
    fn.setNetwork("default");
    fn.network_id = null;
    return fn;
  };

  // Accepts a contract object created with web3.eth.contract.
  // Optionally, if called without `new`, accepts a network_id and will
  // create a new version of the contract abstraction with that network_id set.
  function Contract() {
    if (this instanceof Contract) {
      instantiate(this, arguments[0]);
    } else {
      var C = mutate(Contract);
      var network_id = arguments.length > 0 ? arguments[0] : "default";
      C.setNetwork(network_id);
      return C;
    }
  };

  Contract.currentProvider = null;

  Contract.setProvider = function(provider) {
    var wrapped = new Provider(provider);
    this.web3.setProvider(wrapped);
    this.currentProvider = provider;
  };

  Contract.new = function() {
    if (this.currentProvider == null) {
      throw new Error("Crowdsale error: Please call setProvider() first before calling new().");
    }

    var args = Array.prototype.slice.call(arguments);

    if (!this.unlinked_binary) {
      throw new Error("Crowdsale error: contract binary not set. Can't deploy new instance.");
    }

    var regex = /__[^_]+_+/g;
    var unlinked_libraries = this.binary.match(regex);

    if (unlinked_libraries != null) {
      unlinked_libraries = unlinked_libraries.map(function(name) {
        // Remove underscores
        return name.replace(/_/g, "");
      }).sort().filter(function(name, index, arr) {
        // Remove duplicates
        if (index + 1 >= arr.length) {
          return true;
        }

        return name != arr[index + 1];
      }).join(", ");

      throw new Error("Crowdsale contains unresolved libraries. You must deploy and link the following libraries before you can deploy a new version of Crowdsale: " + unlinked_libraries);
    }

    var self = this;

    return new Promise(function(accept, reject) {
      var contract_class = self.web3.eth.contract(self.abi);
      var tx_params = {};
      var last_arg = args[args.length - 1];

      // It's only tx_params if it's an object and not a BigNumber.
      if (Utils.is_object(last_arg) && !Utils.is_big_number(last_arg)) {
        tx_params = args.pop();
      }

      tx_params = Utils.merge(self.class_defaults, tx_params);

      if (tx_params.data == null) {
        tx_params.data = self.binary;
      }

      // web3 0.9.0 and above calls new twice this callback twice.
      // Why, I have no idea...
      var intermediary = function(err, web3_instance) {
        if (err != null) {
          reject(err);
          return;
        }

        if (err == null && web3_instance != null && web3_instance.address != null) {
          accept(new self(web3_instance));
        }
      };

      args.push(tx_params, intermediary);
      contract_class.new.apply(contract_class, args);
    });
  };

  Contract.at = function(address) {
    if (address == null || typeof address != "string" || address.length != 42) {
      throw new Error("Invalid address passed to Crowdsale.at(): " + address);
    }

    var contract_class = this.web3.eth.contract(this.abi);
    var contract = contract_class.at(address);

    return new this(contract);
  };

  Contract.deployed = function() {
    if (!this.address) {
      throw new Error("Cannot find deployed address: Crowdsale not deployed or address not set.");
    }

    return this.at(this.address);
  };

  Contract.defaults = function(class_defaults) {
    if (this.class_defaults == null) {
      this.class_defaults = {};
    }

    if (class_defaults == null) {
      class_defaults = {};
    }

    var self = this;
    Object.keys(class_defaults).forEach(function(key) {
      var value = class_defaults[key];
      self.class_defaults[key] = value;
    });

    return this.class_defaults;
  };

  Contract.extend = function() {
    var args = Array.prototype.slice.call(arguments);

    for (var i = 0; i < arguments.length; i++) {
      var object = arguments[i];
      var keys = Object.keys(object);
      for (var j = 0; j < keys.length; j++) {
        var key = keys[j];
        var value = object[key];
        this.prototype[key] = value;
      }
    }
  };

  Contract.all_networks = {
  "default": {
    "abi": [
      {
        "constant": false,
        "inputs": [],
        "name": "openAuction",
        "outputs": [
          {
            "name": "success",
            "type": "bool"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "deadline",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [],
        "name": "auctionEnd",
        "outputs": [
          {
            "name": "",
            "type": "bool"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [
          {
            "name": "groupId",
            "type": "uint256"
          },
          {
            "name": "bidderId",
            "type": "string"
          },
          {
            "name": "name",
            "type": "string"
          },
          {
            "name": "value",
            "type": "uint256"
          }
        ],
        "name": "sendBid",
        "outputs": [
          {
            "name": "finalValue",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "latePaymentInterest",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [],
        "name": "invoicePaymentReceived",
        "outputs": [],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [],
        "name": "isDeadlineReached",
        "outputs": [
          {
            "name": "",
            "type": "bool"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "borrowerId",
        "outputs": [
          {
            "name": "",
            "type": "string"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "invoiceId",
        "outputs": [
          {
            "name": "",
            "type": "string"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "invoiceAmount",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "fundingGoal",
        "outputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [],
        "name": "owner",
        "outputs": [
          {
            "name": "",
            "type": "address"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": true,
        "inputs": [
          {
            "name": "",
            "type": "uint256"
          }
        ],
        "name": "groups",
        "outputs": [
          {
            "name": "groupId",
            "type": "uint256"
          },
          {
            "name": "groupName",
            "type": "string"
          },
          {
            "name": "goal",
            "type": "uint256"
          },
          {
            "name": "amountRaised",
            "type": "uint256"
          },
          {
            "name": "isWinner",
            "type": "bool"
          },
          {
            "name": "isRefunded",
            "type": "bool"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [
          {
            "name": "_name",
            "type": "string"
          },
          {
            "name": "_goal",
            "type": "uint256"
          }
        ],
        "name": "createGroup",
        "outputs": [
          {
            "name": "success",
            "type": "bool"
          }
        ],
        "payable": false,
        "type": "function"
      },
      {
        "constant": false,
        "inputs": [
          {
            "name": "newOwner",
            "type": "address"
          }
        ],
        "name": "transferOwnership",
        "outputs": [],
        "payable": false,
        "type": "function"
      },
      {
        "inputs": [
          {
            "name": "_currencyToken",
            "type": "address"
          },
          {
            "name": "_borrowerId",
            "type": "string"
          },
          {
            "name": "_borrowerName",
            "type": "string"
          },
          {
            "name": "_buyerName",
            "type": "string"
          },
          {
            "name": "_invoiceId",
            "type": "string"
          },
          {
            "name": "_invoiceAmount",
            "type": "uint256"
          },
          {
            "name": "_fundingGoal",
            "type": "uint256"
          }
        ],
        "payable": false,
        "type": "constructor"
      },
      {
        "anonymous": false,
        "inputs": [
          {
            "indexed": false,
            "name": "groupId",
            "type": "uint256"
          },
          {
            "indexed": false,
            "name": "name",
            "type": "string"
          },
          {
            "indexed": false,
            "name": "goal",
            "type": "uint256"
          }
        ],
        "name": "EventGroupCreated",
        "type": "event"
      },
      {
        "anonymous": false,
        "inputs": [
          {
            "indexed": false,
            "name": "groupId",
            "type": "uint256"
          },
          {
            "indexed": false,
            "name": "_name",
            "type": "string"
          },
          {
            "indexed": false,
            "name": "goal",
            "type": "uint256"
          }
        ],
        "name": "EventGroupGoalReached",
        "type": "event"
      },
      {
        "anonymous": false,
        "inputs": [
          {
            "indexed": false,
            "name": "groupId",
            "type": "uint256"
          },
          {
            "indexed": false,
            "name": "bidderId",
            "type": "string"
          },
          {
            "indexed": false,
            "name": "name",
            "type": "string"
          },
          {
            "indexed": false,
            "name": "value",
            "type": "uint256"
          }
        ],
        "name": "EventNewBid",
        "type": "event"
      }
    ],
    "unlinked_binary": "0x60606040526000600255346200000057604051620013e7380380620013e783398101604090815281516020830151918301516060840151608085015160a086015160c0870151949695860195938401949284019391909101915b5b60008054600160a060020a03191633600160a060020a03161790555b8560049080519060200190828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f10620000c457805160ff1916838001178555620000f4565b82800160010185558215620000f4579182015b82811115620000f4578251825591602001919060010190620000d7565b5b50620001189291505b80821115620001145760008155600101620000fe565b5090565b50508460059080519060200190828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f106200016857805160ff191683800117855562000198565b8280016001018555821562000198579182015b82811115620001985782518255916020019190600101906200017b565b5b50620001bc9291505b80821115620001145760008155600101620000fe565b5090565b50508360069080519060200190828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f106200020c57805160ff19168380011785556200023c565b828001600101855582156200023c579182015b828111156200023c5782518255916020019190600101906200021f565b5b50620002609291505b80821115620001145760008155600101620000fe565b5090565b50508260039080519060200190828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f10620002b057805160ff1916838001178555620002e0565b82800160010185558215620002e0579182015b82811115620002e0578251825591602001919060010190620002c3565b5b50620003049291505b80821115620001145760008155600101620000fe565b5090565b5050600782905560088190554262015180016009556000805460a060020a60ff02191690555b505050505050505b6110a580620003426000396000f300606060405236156100bf5763ffffffff60e060020a60003504166304cb72f981146100c457806329dcb0cf146100e55780632a24f46c14610104578063338f5f5d1461012557806333f84b53146101ca578063480ed228146101e95780635f1c1a97146101f85780636fbefedf1461021957806370c86286146102a65780637478901d146103335780637a3a0e84146103525780638da5cb5b1461037157806396324bd41461039a578063e367fc6a1461045b578063f2fde38b146104c4575b610000565b34610000576100d16104df565b604080519115158252519081900360200190f35b34610000576100f261053e565b60408051918252519081900360200190f35b34610000576100d1610544565b604080519115158252519081900360200190f35b346100005760408051602060046024803582810135601f81018590048502860185019096528585526100f2958335959394604494939290920191819084018382808284375050604080516020601f89358b01803591820183900483028401830190945280835297999881019791965091820194509250829150840183828082843750949650509335935061059092505050565b60408051918252519081900360200190f35b34610000576100f2610a5f565b60408051918252519081900360200190f35b34610000576101f6610a65565b005b34610000576100d1610aca565b604080519115158252519081900360200190f35b3461000057610226610b2b565b60408051602080825283518183015283519192839290830191850190808383821561026c575b80518252602083111561026c57601f19909201916020918201910161024c565b505050905090810190601f1680156102985780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b3461000057610226610bb9565b60408051602080825283518183015283519192839290830191850190808383821561026c575b80518252602083111561026c57601f19909201916020918201910161024c565b505050905090810190601f1680156102985780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b34610000576100f2610c47565b60408051918252519081900360200190f35b34610000576100f2610c4d565b60408051918252519081900360200190f35b346100005761037e610c53565b60408051600160a060020a039092168252519081900360200190f35b34610000576103aa600435610c62565b6040805187815290810185905260608101849052821515608082015281151560a082015260c0602082018181528754600260001961010060018416150201909116049183018290529060e0830190889080156104475780601f1061041c57610100808354040283529160200191610447565b820191906000526020600020905b81548152906001019060200180831161042a57829003601f168201915b505097505050505050505060405180910390f35b34610000576100d1600480803590602001908201803590602001908080601f016020809104026020016040519081016040528093929190818152602001838380828437509496505093359350610cab92505050565b604080519115158252519081900360200190f35b34610000576101f6600160a060020a0360043516610fe0565b005b6000805433600160a060020a039081169116146104fb57610000565b6000805460a060020a900460ff166004811161000057141561053557506000805460a060020a60ff02191660a060020a1790556001610539565b5060005b5b5b90565b60095481565b6000600260005460ff60a060020a9091041660048111610000571415610539576000805460a060020a60ff021916740300000000000000000000000000000000000000001790555b5b90565b600080600160005460ff60a060020a909104166004811161000057146105b557610000565b600a86815481101561000057906000526020600020906006020160005b5090506105dd610aca565b1515600114806105eb575082155b806105f857506002810154155b1561060257610000565b80600201548382600401540111156106295761062681600201548260040154611028565b92505b8381600301866040518082805190602001908083835b6020831061065e5780518252601f19909201916020918201910161063f565b6001836020036101000a03801982511681845116808217855250505050505090500191505090815260200160405180910390206001019080519060200190828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f106106dd57805160ff191683800117855561070a565b8280016001018555821561070a579182015b8281111561070a5782518255916020019190600101906106ef565b5b5061072b9291505b808211156107275760008155600101610713565b5090565b505061079d81600301866040518082805190602001908083835b602083106107645780518252601f199092019160209182019101610745565b51815160209384036101000a60001901801990921691161790529201948552506040519384900301909220600201549150859050611041565b81600301866040518082805190602001908083835b602083106107d15780518252601f1990920191602091820191016107b2565b51815160209384036101000a6000190180199092169116179052920194855250604051938490030190922060020192909255505060048101546108149084611041565b81600401819055507f9f43fe110c06806f41ec29f9645025d20b48cc4791a37f018a09c7a1846c07a78686868660405180858152602001806020018060200184815260200183810383528681815181526020019150805190602001908083836000831461089c575b80518252602083111561089c57601f19909201916020918201910161087c565b505050905090810190601f1680156108c85780820380516001836020036101000a031916815260200191505b5083810382528551815285516020918201918701908083838215610907575b80518252602083111561090757601f1990920191602091820191016108e7565b505050905090810190601f1680156109335780820380516001836020036101000a031916815260200191505b50965050505050505060405180910390a1806002015481600401541415610a515760058101805460ff19166001179055600080546002919060a060020a60ff02191660a060020a8302179055507ffc283d648f2d223664cf7012091e001a932bf7f34644e0f5f58196aab51df5a7868260010183600201546040518084815260200180602001838152602001828103825284818154600181600116156101000203166002900481526020019150805460018160011615610100020316600290048015610a405780601f10610a1557610100808354040283529160200191610a40565b820191906000526020600020905b815481529060010190602001808311610a2357829003601f168201915b505094505050505060405180910390a15b8291505b5b50949350505050565b60025481565b60005433600160a060020a03908116911614610a8057610000565b600360005460ff60a060020a9091041660048111610000571415610ac6576000805460a060020a60ff021916740400000000000000000000000000000000000000001790555b5b5b565b600060095442111561053557600160005460ff60a060020a9091041660048111610000571415610b1c576000805460a060020a60ff021916740200000000000000000000000000000000000000001790555b506001610539565b5060005b90565b6004805460408051602060026001851615610100026000190190941693909304601f81018490048402820184019092528181529291830182828015610bb15780601f10610b8657610100808354040283529160200191610bb1565b820191906000526020600020905b815481529060010190602001808311610b9457829003601f168201915b505050505081565b6003805460408051602060026001851615610100026000190190941693909304601f81018490048402820184019092528181529291830182828015610bb15780601f10610b8657610100808354040283529160200191610bb1565b820191906000526020600020905b815481529060010190602001808311610b9457829003601f168201915b505050505081565b60075481565b60085481565b600054600160a060020a031681565b600a81815481101561000057906000526020600020906006020160005b508054600282015460048301546005840154929450600190930192909160ff8082169161010090041686565b6000600160005460ff60a060020a90910416600481116100005714610ccf57610000565b610cd7610aca565b158015610ce657506008548210155b8015610cf457506007548211155b15610fd457600a8054806001018281815481835581811511610dc257600602816006028360005260206000209182019101610dc291905b80821115610727576000600082016000905560018201805460018160011615610100020316600290046000825580601f10610d665750610d98565b601f016020900490600052602060002090810190610d9891905b808211156107275760008155600101610713565b5090565b5b5050600060028201819055600482015560058101805461ffff19169055600601610d2b565b5090565b5b505050916000526020600020906006020160005b60c060405190810160405280600a80549050815260200187815260200186815260200160008152602001600015158152602001600015158152509091909150600082015181600001556020820151816001019080519060200190828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f10610e7257805160ff1916838001178555610e9f565b82800160010185558215610e9f579182015b82811115610e9f578251825591602001919060010190610e84565b5b50610ec09291505b808211156107275760008155600101610713565b5090565b5050604082810151600283015560608084015160048401556080808501516005909401805460a09096015115156101000261ff001995151560ff19909716969096179490941694909417909255600a54815160001991909101808252918101879052602080820184815289519483019490945288517f8aceed8de06c3ec19c51e5ab9c1ca2eb054cbd116661d1282071fd7703cc353e96509294899489949092918401918601908083838215610f91575b805182526020831115610f9157601f199092019160209182019101610f71565b505050905090810190601f168015610fbd5780820380516001836020036101000a031916815260200191505b5094505050505060405180910390a1506001610fd8565b5060005b5b5b92915050565b60005433600160a060020a03908116911614610ffb57610000565b6000805473ffffffffffffffffffffffffffffffffffffffff1916600160a060020a0383161790555b5b50565b600061103683831115611069565b508082035b92915050565b600082820161105e8482108015906110595750838210155b611069565b8091505b5092915050565b80151561102457610000565b5b505600a165627a7a72305820f37300a7ae0b083f82ef6d3951ce8185e33d8ca4f424bc05210fa3a02f070a6d0029",
    "events": {
      "0x8aceed8de06c3ec19c51e5ab9c1ca2eb054cbd116661d1282071fd7703cc353e": {
        "anonymous": false,
        "inputs": [
          {
            "indexed": false,
            "name": "groupId",
            "type": "uint256"
          },
          {
            "indexed": false,
            "name": "name",
            "type": "string"
          },
          {
            "indexed": false,
            "name": "goal",
            "type": "uint256"
          }
        ],
        "name": "EventGroupCreated",
        "type": "event"
      },
      "0xfc283d648f2d223664cf7012091e001a932bf7f34644e0f5f58196aab51df5a7": {
        "anonymous": false,
        "inputs": [
          {
            "indexed": false,
            "name": "groupId",
            "type": "uint256"
          },
          {
            "indexed": false,
            "name": "_name",
            "type": "string"
          },
          {
            "indexed": false,
            "name": "goal",
            "type": "uint256"
          }
        ],
        "name": "EventGroupGoalReached",
        "type": "event"
      },
      "0x9f43fe110c06806f41ec29f9645025d20b48cc4791a37f018a09c7a1846c07a7": {
        "anonymous": false,
        "inputs": [
          {
            "indexed": false,
            "name": "groupId",
            "type": "uint256"
          },
          {
            "indexed": false,
            "name": "bidderId",
            "type": "string"
          },
          {
            "indexed": false,
            "name": "name",
            "type": "string"
          },
          {
            "indexed": false,
            "name": "value",
            "type": "uint256"
          }
        ],
        "name": "EventNewBid",
        "type": "event"
      }
    },
    "updated_at": 1487619399762,
    "links": {}
  }
};

  Contract.checkNetwork = function(callback) {
    var self = this;

    if (this.network_id != null) {
      return callback();
    }

    this.web3.version.network(function(err, result) {
      if (err) return callback(err);

      var network_id = result.toString();

      // If we have the main network,
      if (network_id == "1") {
        var possible_ids = ["1", "live", "default"];

        for (var i = 0; i < possible_ids.length; i++) {
          var id = possible_ids[i];
          if (Contract.all_networks[id] != null) {
            network_id = id;
            break;
          }
        }
      }

      if (self.all_networks[network_id] == null) {
        return callback(new Error(self.name + " error: Can't find artifacts for network id '" + network_id + "'"));
      }

      self.setNetwork(network_id);
      callback();
    })
  };

  Contract.setNetwork = function(network_id) {
    var network = this.all_networks[network_id] || {};

    this.abi             = this.prototype.abi             = network.abi;
    this.unlinked_binary = this.prototype.unlinked_binary = network.unlinked_binary;
    this.address         = this.prototype.address         = network.address;
    this.updated_at      = this.prototype.updated_at      = network.updated_at;
    this.links           = this.prototype.links           = network.links || {};
    this.events          = this.prototype.events          = network.events || {};

    this.network_id = network_id;
  };

  Contract.networks = function() {
    return Object.keys(this.all_networks);
  };

  Contract.link = function(name, address) {
    if (typeof name == "function") {
      var contract = name;

      if (contract.address == null) {
        throw new Error("Cannot link contract without an address.");
      }

      Contract.link(contract.contract_name, contract.address);

      // Merge events so this contract knows about library's events
      Object.keys(contract.events).forEach(function(topic) {
        Contract.events[topic] = contract.events[topic];
      });

      return;
    }

    if (typeof name == "object") {
      var obj = name;
      Object.keys(obj).forEach(function(name) {
        var a = obj[name];
        Contract.link(name, a);
      });
      return;
    }

    Contract.links[name] = address;
  };

  Contract.contract_name   = Contract.prototype.contract_name   = "Crowdsale";
  Contract.generated_with  = Contract.prototype.generated_with  = "3.2.0";

  // Allow people to opt-in to breaking changes now.
  Contract.next_gen = false;

  var properties = {
    binary: function() {
      var binary = Contract.unlinked_binary;

      Object.keys(Contract.links).forEach(function(library_name) {
        var library_address = Contract.links[library_name];
        var regex = new RegExp("__" + library_name + "_*", "g");

        binary = binary.replace(regex, library_address.replace("0x", ""));
      });

      return binary;
    }
  };

  Object.keys(properties).forEach(function(key) {
    var getter = properties[key];

    var definition = {};
    definition.enumerable = true;
    definition.configurable = false;
    definition.get = getter;

    Object.defineProperty(Contract, key, definition);
    Object.defineProperty(Contract.prototype, key, definition);
  });

  bootstrap(Contract);

  if (typeof module != "undefined" && typeof module.exports != "undefined") {
    module.exports = Contract;
  } else {
    // There will only be one version of this contract in the browser,
    // and we can use that.
    window.Crowdsale = Contract;
  }
})();
