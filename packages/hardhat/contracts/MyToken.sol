// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyToken is ERC20, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    uint256 private constant INITIAL_SUPPLY = 1000000 * 10**18;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffPeriod;
    }

    mapping(address => mapping(uint256 => VestingSchedule)) private vestingSchedules;
    mapping(address => Counters.Counter) private vestingScheduleCount;

    event TokensVested(address indexed beneficiary, uint256 indexed scheduleId, uint256 amount);
    event VestingScheduleCreated(address indexed beneficiary, uint256 indexed scheduleId, uint256 amount);

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(_msgSender(), INITIAL_SUPPLY);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 duration,
        uint256 cliffPeriod
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(amount > 0, "Vesting amount must be greater than 0");
        require(balanceOf(_msgSender()) >= amount, "Insufficient balance for vesting");
        require(duration > cliffPeriod, "Duration must be greater than cliff period");

        uint256 scheduleId = vestingScheduleCount[beneficiary].current();
        vestingScheduleCount[beneficiary].increment();

        _transfer(_msgSender(), address(this), amount);

        uint256 currentTime = block.timestamp;
        VestingSchedule storage schedule = vestingSchedules[beneficiary][scheduleId];
        schedule.totalAmount = amount;
        schedule.startTime = currentTime;
        schedule.duration = duration;
        schedule.cliffPeriod = cliffPeriod;

        emit VestingScheduleCreated(beneficiary, scheduleId, amount);
    }

    function releaseVestedTokens(uint256 scheduleId) external {
        VestingSchedule storage schedule = vestingSchedules[_msgSender()][scheduleId];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(block.timestamp > schedule.startTime.add(schedule.cliffPeriod), "Cliff period has not ended");

        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 releaseableAmount = vestedAmount.sub(schedule.releasedAmount);

        require(releaseableAmount > 0, "No tokens available for release");

        schedule.releasedAmount = schedule.releasedAmount.add(releaseableAmount);
        _transfer(address(this), _msgSender(), releaseableAmount);

        emit TokensVested(_msgSender(), scheduleId, releaseableAmount);
    }

    function getVestedAmount(address beneficiary, uint256 scheduleId) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary][scheduleId];
        return _calculateVestedAmount(schedule);
    }

    function getVestingScheduleCount(address beneficiary) external view returns (uint256) {
        return vestingScheduleCount[beneficiary].current();
    }

    function _calculateVestedAmount(VestingSchedule storage schedule) private view returns (uint256) {
        if (block.timestamp <= schedule.startTime.add(schedule.cliffPeriod)) {
            return 0;
        } else if (block.timestamp >= schedule.startTime.add(schedule.duration)) {
            return schedule.totalAmount;
        } else {
            return schedule.totalAmount.mul(block.timestamp.sub(schedule.startTime.add(schedule.cliffPeriod)))
                .div(schedule.duration.sub(schedule.cliffPeriod));
        }
    }
}