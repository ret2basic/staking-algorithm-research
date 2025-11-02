// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call(data);
        if (success) {
            return returndata;
        }

        if (returndata.length > 0) {
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        }

        revert(errorMessage);
    }
}
