# SAS AML/CDD Code Accelerator

## Overview

This repository contains programs and macros to accelerate implementation efforts with SAS Anti-Money Laundering and SAS Customer Due Diligence products.  

### Prerequisites
 
- SAS Anti-Money Laundering 8.3 or SAS Customer Due Diligence 8.3

### Installation
 
Once your SAS environment ready, you can clone this project and begin personalizing it for use.

#### Clone this Project
 
Run the following commands from a terminal session where SPRE has been deployed:

```
# clone this repo
git clone https://github.com/sassoftware/sas-aml-cdd-accelerator

# move to project directory
cd sas-aml-cdd-accelerator
```

#### Customize Environment Variables
 
A few environment variables are needed in a `env_usermods.cfg` file located in the conf directory. The env_usermods.cfg.sample exists as a template to follow.  If this file is not manually generated, then the job execution will prepare it for you when fired.

After providing the environment details, the first thing you will need to do is setup your [sas wallet](#sas-wallet).

## Getting Started

The details on how to setup the wallet are under`<repository_root>/macros/sas_wallet.sas` at the top.  General directions outlined below for convenience.

The sas_wallet is a secure dataset that will store credentials you will use to obtain an oauth token for batch operations.  The codebase is explicitly looking for WS_USER and WS_PASSWORD, here are the overall steps:

    ```
    %include "/path/to/sas_wallet.sas";
    %sas_wallet(create);
    %sas_wallet(put,WS_USER,{USER}); /* e.g. batch userid */
    %sas_wallet(put,WS_PASSWORD,{PASSWORD}); /* e.g. batch password */
    ```

Once the wallet is setup, you can run a test job.

Below are details around execution or usage of the various programs within this project with examples.

<details><summary>Batch Execution</summary>

   USAGE: `sas_jobexec.sh -p [program] -t [tenant] -d [debug|DEBUG_MACRO,DEBUG_ALL]`
   
   EXAMPLE: `nohup ./sas_jobexec.sh -p testprogram.sas -t mytenant -d DEBUG_ALL &`

    -p - looks for the program under <repository_root>/programs/
    -t - specifies which tenant your wanting to run against

The batch job will automatically call `<repository_root>/programs/user_autoexec.sas` which has some postgres libnames already available.  You can also call one of the many product autoexecs (e.g. cdd_autoexec;) in your sas program as needed.

</details>

## Contributing

We welcome your contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to submit contributions to this project.


## License

This project is licensed under the [Apache 2.0 License](LICENSE).

## Additional Resources

