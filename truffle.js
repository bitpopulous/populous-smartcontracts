module.exports = {
    build: {
        "index.html": "index.html",
        "app.js": [
            "javascripts/app.js"
        ],
        "app.css": [
            "stylesheets/app.css"
        ],
        "images/": "images/"
    },
    networks: {
        "ropsten": {
            network_id: 3,
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000 //  <=== NEW
        },
        "dev": {
            network_id: "default",
            before_timeout: 300, //  <=== NEW
            test_timeout: 300 //  <=== NEW
        }
    },
    rpc: {
        host: "localhost",
        port: 8545,
    }
};